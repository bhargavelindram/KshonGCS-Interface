//! Initial dependency-free project primitives.
use std::path::{Path,PathBuf};
#[derive(Debug,Clone,PartialEq,Eq)]
pub enum ProjectKind{TwoD,ThreeD,Hybrid}
#[derive(Debug,Clone,PartialEq,Eq)]
pub struct ProjectDescriptor{pub name:String,pub root:PathBuf,pub kind:ProjectKind}
impl ProjectDescriptor{
 pub fn new(name:impl Into<String>,root:impl AsRef<Path>,kind:ProjectKind)->Self{Self{name:name.into(),root:root.as_ref().to_path_buf(),kind}}
 pub fn metadata_path(&self)->PathBuf{self.root.join("project.kshon.json")}
}
#[cfg(test)]mod tests{use super::*;#[test]fn metadata_path_is_inside_project_root(){let p=ProjectDescriptor::new("Example","/tmp/Example",ProjectKind::ThreeD);assert_eq!(p.metadata_path(),PathBuf::from("/tmp/Example/project.kshon.json"));}}
