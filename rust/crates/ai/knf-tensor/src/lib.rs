//! Foundational CPU tensor storage for the Kshon Neural Framework.
//! This crate intentionally starts with safe, contiguous f32 storage and no external dependencies.

use std::error::Error;
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TensorError {
    InvalidShape,
    ShapeOverflow,
    DataLengthMismatch { expected: usize, actual: usize },
    IndexOutOfBounds { index: Vec<usize>, shape: Vec<usize> },
    ElementCountMismatch { expected: usize, actual: usize },
    InvalidDimension,
    AllocationFailed,
}
impl fmt::Display for TensorError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidShape => write!(f, "tensor shape must contain at least one dimension"),
            Self::ShapeOverflow => write!(f, "tensor shape element count overflowed usize"),
            Self::DataLengthMismatch { expected, actual } => write!(f, "expected {expected} values, received {actual}"),
            Self::IndexOutOfBounds { index, shape } => write!(f, "index {index:?} is outside tensor shape {shape:?}"),
            Self::ElementCountMismatch { expected, actual } => write!(f, "reshape requires {expected} elements, tensor contains {actual}"),
            Self::InvalidDimension => write!(f, "dimension is invalid for this tensor"),
            Self::AllocationFailed => write!(f, "unable to allocate tensor storage"),
        }
    }
}
impl Error for TensorError {}

#[derive(Debug, Clone, PartialEq)]
pub struct Tensor {
    shape: Vec<usize>,
    data: Vec<f32>,
}
impl Tensor {
    pub fn from_vec(shape: impl Into<Vec<usize>>, data: Vec<f32>) -> Result<Self, TensorError> {
        let shape = shape.into();
        let expected = element_count(&shape)?;
        if expected != data.len() {
            return Err(TensorError::DataLengthMismatch { expected, actual: data.len() });
        }
        Ok(Self { shape, data })
    }
    pub fn zeros(shape: impl Into<Vec<usize>>) -> Result<Self, TensorError> {
        Self::filled(shape.into(), 0.0)
    }
    pub fn ones(shape: impl Into<Vec<usize>>) -> Result<Self, TensorError> {
        Self::filled(shape.into(), 1.0)
    }
    fn filled(shape: Vec<usize>, value: f32) -> Result<Self, TensorError> {
        let count = element_count(&shape)?;
        let mut data = Vec::new();
        data.try_reserve_exact(count).map_err(|_| TensorError::AllocationFailed)?;
        data.resize(count, value);
        Ok(Self { shape, data })
    }
    pub fn shape(&self) -> &[usize] { &self.shape }
    pub fn rank(&self) -> usize { self.shape.len() }
    pub fn len(&self) -> usize { self.data.len() }
    pub fn is_empty(&self) -> bool { self.data.is_empty() }
    pub fn data(&self) -> &[f32] { &self.data }
    pub fn data_mut(&mut self) -> &mut [f32] { &mut self.data }
    pub fn reshape(&mut self, shape: impl Into<Vec<usize>>) -> Result<(), TensorError> {
        let shape = shape.into();
        let expected = element_count(&shape)?;
        if expected != self.data.len() {
            return Err(TensorError::ElementCountMismatch { expected, actual: self.data.len() });
        }
        self.shape = shape;
        Ok(())
    }
    pub fn get(&self, index: &[usize]) -> Result<f32, TensorError> {
        let offset = self.offset(index)?;
        Ok(self.data[offset])
    }
    pub fn set(&mut self, index: &[usize], value: f32) -> Result<(), TensorError> {
        let offset = self.offset(index)?;
        self.data[offset] = value;
        Ok(())
    }
    fn offset(&self, index: &[usize]) -> Result<usize, TensorError> {
        if index.len() != self.shape.len() || index.iter().zip(&self.shape).any(|(i, d)| i >= d) {
            return Err(TensorError::IndexOutOfBounds { index: index.to_vec(), shape: self.shape.clone() });
        }
        let mut offset = 0usize;
        for (&i, &dim) in index.iter().zip(&self.shape) {
            offset = offset.checked_mul(dim).and_then(|v| v.checked_add(i)).ok_or(TensorError::ShapeOverflow)?;
        }
        Ok(offset)
    }
}
fn element_count(shape: &[usize]) -> Result<usize, TensorError> {
    if shape.is_empty() { return Err(TensorError::InvalidShape); }
    shape.iter().try_fold(1usize, |n, &d| n.checked_mul(d).ok_or(TensorError::ShapeOverflow))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn constructs_and_indexes_matrix() {
        let mut t = Tensor::from_vec(vec![2, 3], vec![1., 2., 3., 4., 5., 6.]).unwrap();
        assert_eq!(t.get(&[1, 2]).unwrap(), 6.);
        t.set(&[0, 1], 9.).unwrap();
        assert_eq!(t.data(), &[1., 9., 3., 4., 5., 6.]);
    }
    #[test] fn reshape_preserves_element_count() {
        let mut t = Tensor::ones(vec![2, 3]).unwrap();
        t.reshape(vec![3, 2]).unwrap();
        assert_eq!(t.shape(), &[3, 2]);
    }
    #[test] fn rejects_mismatched_data() {
        assert!(matches!(Tensor::from_vec(vec![2, 2], vec![1., 2.]), Err(TensorError::DataLengthMismatch { .. })));
    }
    #[test] fn rejects_invalid_indices() {
        let t = Tensor::zeros(vec![2, 2]).unwrap();
        assert!(matches!(t.get(&[2, 0]), Err(TensorError::IndexOutOfBounds { .. })));
    }
    #[test] fn rejects_shape_overflow() {
        assert!(matches!(Tensor::zeros(vec![usize::MAX, 2]), Err(TensorError::ShapeOverflow)));
    }
}
