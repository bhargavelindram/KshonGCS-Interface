//! Stable identifiers and basic scene primitives for Kshon Engine.
use std::collections::BTreeMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct EntityId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Vec3 { pub x: f32, pub y: f32, pub z: f32 }
impl Vec3 {
    pub const ZERO: Self = Self { x: 0.0, y: 0.0, z: 0.0 };
    pub const ONE: Self = Self { x: 1.0, y: 1.0, z: 1.0 };
    pub const fn new(x: f32, y: f32, z: f32) -> Self { Self { x, y, z } }
}
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Transform { pub translation: Vec3, pub rotation_euler: Vec3, pub scale: Vec3 }
impl Default for Transform {
    fn default() -> Self { Self { translation: Vec3::ZERO, rotation_euler: Vec3::ZERO, scale: Vec3::ONE } }
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Entity { pub id: EntityId, pub name: String, pub parent: Option<EntityId> }
#[derive(Debug, Default)]
pub struct Scene {
    next_id: u64,
    entities: BTreeMap<EntityId, Entity>,
    transforms: BTreeMap<EntityId, Transform>,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SceneError { EntityNotFound(EntityId), ParentNotFound(EntityId), ParentCycle }
impl Scene {
    pub fn new() -> Self { Self::default() }
    pub fn spawn(&mut self, name: impl Into<String>, parent: Option<EntityId>) -> Result<EntityId, SceneError> {
        if let Some(id) = parent { if !self.entities.contains_key(&id) { return Err(SceneError::ParentNotFound(id)); } }
        self.next_id = self.next_id.checked_add(1).expect("entity identifier space exhausted");
        let id = EntityId(self.next_id);
        self.entities.insert(id, Entity { id, name: name.into(), parent });
        self.transforms.insert(id, Transform::default());
        Ok(id)
    }
    pub fn entity(&self, id: EntityId) -> Option<&Entity> { self.entities.get(&id) }
    pub fn transform(&self, id: EntityId) -> Option<&Transform> { self.transforms.get(&id) }
    pub fn transform_mut(&mut self, id: EntityId) -> Option<&mut Transform> { self.transforms.get_mut(&id) }
    pub fn len(&self) -> usize { self.entities.len() }
    pub fn is_empty(&self) -> bool { self.entities.is_empty() }
    pub fn remove(&mut self, id: EntityId) -> Result<(), SceneError> {
        if !self.entities.contains_key(&id) { return Err(SceneError::EntityNotFound(id)); }
        let children: Vec<_> = self.entities.values().filter(|e| e.parent == Some(id)).map(|e| e.id).collect();
        for child in children { self.remove(child)?; }
        self.entities.remove(&id);
        self.transforms.remove(&id);
        Ok(())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn creates_parented_entities_with_transforms() {
        let mut scene = Scene::new();
        let root = scene.spawn("Root", None).unwrap();
        let child = scene.spawn("Player", Some(root)).unwrap();
        assert_eq!(scene.entity(child).unwrap().parent, Some(root));
        assert_eq!(scene.transform(child), Some(&Transform::default()));
    }
    #[test] fn removing_parent_removes_descendants() {
        let mut scene = Scene::new();
        let root = scene.spawn("Root", None).unwrap();
        let child = scene.spawn("Child", Some(root)).unwrap();
        scene.remove(root).unwrap();
        assert!(scene.entity(child).is_none());
        assert!(scene.is_empty());
    }
}
