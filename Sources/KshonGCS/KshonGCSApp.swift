import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@main struct KshonGCSApp: App {
 @StateObject private var store = WorkspaceStore()
 var body: some Scene {
  WindowGroup { MainView().environmentObject(store).frame(minWidth:980,minHeight:650) }
   .commands {
    CommandGroup(replacing:.newItem) { Button("New Game Workspace…"){NotificationCenter.default.post(name:.newProject,object:nil)}.keyboardShortcut("n",modifiers:.command) }
    CommandMenu("Game Creation") { Button("Open Game Creation"){NotificationCenter.default.post(name:.goGameCreation,object:nil)} }\n    CommandMenu("Workspaces") {
     Button("Dashboard"){NotificationCenter.default.post(name:.goDashboard,object:nil)}
     Button("Open Workspace…"){store.openWorkspace()}.keyboardShortcut("o",modifiers:[.command,.shift])
    }
    CommandMenu("Help"){Button("Gameplay Tutorials"){NotificationCenter.default.post(name:.goTutorials,object:nil)}}
   }
 }
}
extension Notification.Name {
 static let newProject=Notification.Name("newProject")
 static let goDashboard=Notification.Name("goDashboard")
 static let goTutorials=Notification.Name("goTutorials")
 static let goWorkspace=Notification.Name("goWorkspace")\n static let goGameCreation=Notification.Name("goGameCreation")
}
struct Project:Identifiable,Codable {
 var id:UUID=UUID(); var name:String; var path:String; var kind:String; var lastOpened:Date=Date(); var thumbnail:String?
 var folder:URL{URL(fileURLWithPath:path,isDirectory:true)}
 var thumbnailURL:URL?{thumbnail.map{folder.appendingPathComponent("Thumbnails").appendingPathComponent($0)}}
}
@MainActor final class WorkspaceStore:ObservableObject {
 @Published var projects:[Project]=[]; @Published var active:Project?; @Published var error:String?
 let fm=FileManager.default
 var registry:URL{fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("KshonGCS/workspaces.json")}
 init(){try? fm.createDirectory(at:registry.deletingLastPathComponent(),withIntermediateDirectories:true);if let d=try? Data(contentsOf:registry),let p=try? JSONDecoder().decode([Project].self,from:d){projects=p.filter{fm.fileExists(atPath:$0.path)}}}
 func save(){do{try JSONEncoder().encode(projects).write(to:registry,options:.atomic)}catch{self.error=error.localizedDescription}}
 func create(name:String,parent:URL,kind:String,image:URL?){
  let n=name.trimmingCharacters(in:.whitespacesAndNewlines);guard !n.isEmpty else{error="Enter a project name.";return}
  let root=parent.appendingPathComponent(n,isDirectory:true)
  do{
   try fm.createDirectory(at:root,withIntermediateDirectories:true)
   for d in ["Scenes","Scripts","Assets/Models","Assets/Textures","Assets/Audio","Assets/Animations","Materials","Prefabs","UI","Blocks","AI","Builds","Cache","Backups","Thumbnails"]{try fm.createDirectory(at:root.appendingPathComponent(d,isDirectory:true),withIntermediateDirectories:true)}
   var thumb:String?
   if let image{let ext=image.pathExtension.isEmpty ? "png":image.pathExtension;thumb="project-thumbnail.\(ext)";try fm.copyItem(at:image,to:root.appendingPathComponent("Thumbnails").appendingPathComponent(thumb!))}
   let p=Project(name:n,path:root.path,kind:kind,thumbnail:thumb);let meta:[String:String]=["id":p.id.uuidString,"name":n,"type":kind,"created":ISO8601DateFormatter().string(from:Date())]
   let data=try JSONSerialization.data(withJSONObject:meta,options:[.prettyPrinted,.sortedKeys]);try data.write(to:root.appendingPathComponent("project.kshon.json"),options:.atomic)
   projects.insert(p,at:0);active=p;save()
  }catch{self.error=error.localizedDescription}
 }
 func open(_ p:Project){var p=p;p.lastOpened=Date();projects.removeAll{$0.id==p.id};projects.insert(p,at:0);active=p;save()}
 func openWorkspace(){
  let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
  guard panel.runModal()==.OK,let url=panel.url else{return}
  guard let d=try? Data(contentsOf:url.appendingPathComponent("project.kshon.json")),let m=try? JSONSerialization.jsonObject(with:d) as? [String:String],let n=m["name"],let k=m["type"] else{error="This folder is not a KshonGCS workspace.";return}
  let thumb=(try? fm.contentsOfDirectory(at:url.appendingPathComponent("Thumbnails"),includingPropertiesForKeys:nil))?.first?.lastPathComponent
  let p=Project(id:UUID(uuidString:m["id"] ?? "") ?? UUID(),name:n,path:url.path,kind:k,thumbnail:thumb);projects.removeAll{$0.path==url.path};projects.insert(p,at:0);active=p;save();NotificationCenter.default.post(name:.goWorkspace,object:nil)
 }
}
struct MainView:View {
 @EnvironmentObject var store:WorkspaceStore;@State var page=0;@State var showCreate=false
 var body:some View{
  ZStack{LinearGradient(colors:[Color(red:0.045,green:0.055,blue:0.08),Color(red:0.09,green:0.08,blue:0.15)],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
   HStack(spacing:0){
    VStack(alignment:.leading,spacing:10){
     HStack(spacing:10){Image(systemName:"gamecontroller.fill").foregroundStyle(.white).frame(width:36,height:36).background(LinearGradient(colors:[.blue,.purple],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:11));VStack(alignment:.leading,spacing:2){Text("KshonGCS").font(.system(size:14,weight:.bold));Text("GAME CREATION STUDIO").font(.system(size:8,weight:.semibold)).tracking(1).foregroundStyle(.secondary)}}.padding(.bottom,22)
     nav("Dashboard","square.grid.2x2",0);nav("Game Creation","hammer.fill",2);nav("Code","chevron.left.forwardslash.chevron.right",3);nav("Tutorials","play.rectangle",1)
     Text("WORKSPACE").font(.system(size:9,weight:.bold)).tracking(1).foregroundStyle(.secondary).padding(.top,20)
     if let p=store.active{Button{page=4}label:{Label(p.name,systemImage:"folder.fill").lineLimit(1).font(.system(size:11))}.buttonStyle(.plain)}else{Text("No workspace open").font(.system(size:10)).foregroundStyle(.tertiary)}
     Spacer();Label("Local mode",systemImage:"circle.fill").font(.system(size:10)).foregroundStyle(.secondary)
    }.padding(18).frame(width:210).background(.ultraThinMaterial)
    Rectangle().fill(.white.opacity(0.08)).frame(width:1)
    Group{if page==0{dashboard}else if page==1{TutorialPage()}else if page==2{GameCreationPage()}else if page==3{CodeWorkspacePage()}else{workspace}}.frame(maxWidth:.infinity,maxHeight:.infinity).transition(.opacity)
   }
  }.preferredColorScheme(.dark).sheet(isPresented:$showCreate){CreateProjectSheet().environmentObject(store)}
   .onReceive(NotificationCenter.default.publisher(for:.newProject)){_ in showCreate=true}
   .onReceive(NotificationCenter.default.publisher(for:.goDashboard)){_ in page=0}
   .onReceive(NotificationCenter.default.publisher(for:.goTutorials)){_ in page=1}
   .onReceive(NotificationCenter.default.publisher(for:.goWorkspace)){_ in page=4}\n   .onReceive(NotificationCenter.default.publisher(for:.goGameCreation)){_ in page=2}
   .alert("KshonGCS",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("OK",role:.cancel){store.error=nil}}message:{Text(store.error ?? "")}
 }
 func nav(_ title:String,_ icon:String,_ index:Int)->some View{Button{withAnimation(.easeInOut(duration:0.2)){page=index}}label:{Label(title,systemImage:icon).font(.system(size:12,weight:.medium)).foregroundStyle(page==index ? .primary:.secondary).padding(10).frame(maxWidth:.infinity,alignment:.leading).background(page==index ? .white.opacity(0.1):.clear,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain)}
 var dashboard:some View{ScrollView{VStack(alignment:.leading,spacing:22){
  HStack{VStack(alignment:.leading,spacing:5){Text("Your creative workspace").font(.system(size:26,weight:.bold,design:.rounded));Text("Build worlds, systems and experiences with KshonGCS.").font(.system(size:12)).foregroundStyle(.secondary)};Spacer();Button{store.openWorkspace()}label:{Label("Open Workspace",systemImage:"folder")}.buttonStyle(GlassButton());Button{showCreate=true}label:{Label("New Game",systemImage:"plus")}.buttonStyle(AccentButton())}.padding(.top,32)
  HStack{quick("Create a game","Start with an empty project","plus.square",.blue){showCreate=true};quick("Learn the engine","Follow a guided tutorial","graduationcap",.purple){page=1}}
  HStack{Text("Recent Workspaces").font(.system(size:16,weight:.semibold));Spacer();Text("\(store.projects.count) projects").font(.system(size:10)).foregroundStyle(.secondary)}
  if store.projects.isEmpty{VStack(spacing:10){Image(systemName:"shippingbox").font(.system(size:30)).foregroundStyle(.secondary);Text("No projects yet").font(.system(size:14,weight:.semibold));Text("Create a workspace or open one from your Mac.").font(.system(size:11)).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(.vertical,38)}
  else{LazyVGrid(columns:[GridItem(.adaptive(minimum:210),spacing:14)],spacing:14){ForEach(store.projects){p in Button{store.open(p);page=4}label:{VStack(alignment:.leading,spacing:9){ZStack{RoundedRectangle(cornerRadius:10).fill(LinearGradient(colors:[.blue.opacity(0.3),.purple.opacity(0.3)],startPoint:.topLeading,endPoint:.bottomTrailing));if let u=p.thumbnailURL,let img=NSImage(contentsOf:u){Image(nsImage:img).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius:10))}else{Image(systemName:"cube.transparent").font(.system(size:34,weight:.light))}}.frame(height:110).clipped();Text(p.name).font(.system(size:12,weight:.semibold));HStack{Text(p.kind);Spacer();Text(p.lastOpened,style:.relative)}.font(.system(size:9)).foregroundStyle(.secondary)}.padding(10).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(.white.opacity(0.08)))}.buttonStyle(.plain)}}}
 }.padding(.horizontal,28).padding(.bottom,30)}}
 func quick(_ title:String,_ detail:String,_ icon:String,_ tint:Color,action:@escaping()->Void)->some View{Button(action:action){HStack(spacing:12){Image(systemName:icon).foregroundStyle(tint).frame(width:40,height:40).background(tint.opacity(0.14),in:RoundedRectangle(cornerRadius:11));VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:12,weight:.semibold));Text(detail).font(.system(size:10)).foregroundStyle(.secondary)};Spacer()}.padding(13).frame(maxWidth:.infinity,alignment:.leading).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(.white.opacity(0.08)))}.buttonStyle(.plain)}
 var workspace:some View{ScrollView{VStack(alignment:.leading,spacing:20){HStack{VStack(alignment:.leading,spacing:5){Text(store.active?.name ?? "Workspace").font(.system(size:25,weight:.bold,design:.rounded));Text(store.active?.path ?? "").font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)};Spacer();Button{page=0}label:{Label("All Projects",systemImage:"square.grid.2x2")}.buttonStyle(GlassButton())}.padding(.top,30);Text("Project Contents").font(.system(size:16,weight:.semibold));LazyVGrid(columns:[GridItem(.adaptive(minimum:150),spacing:12)],spacing:12){ForEach(["Scenes","Scripts","Assets","Materials","Prefabs","UI","Blocks","Builds"],id:\.self){f in Label(f,systemImage:"folder.fill").font(.system(size:12,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading).padding(15).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12))}};Text("Workspace storage is active. The scene editor, AI assistant, asset tools and game runtime are future implementation stages.").font(.system(size:11)).foregroundStyle(.secondary).padding(14).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12))}.padding(.horizontal,28)}}
}
struct CreateProjectSheet:View{
 @EnvironmentObject var store:WorkspaceStore;@Environment(\.dismiss) var dismiss
 @State var name="";@State var kind="3D Game";@State var parent=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("KshonGCS Projects",isDirectory:true);@State var image:URL?
 var body:some View{VStack(alignment:.leading,spacing:16){Text("Create a Game").font(.system(size:20,weight:.bold));TextField("Project name",text:$name).textFieldStyle(.roundedBorder);Picker("Project Type",selection:$kind){Text("2D Game").tag("2D Game");Text("3D Game").tag("3D Game");Text("2D + 3D").tag("2D + 3D")};HStack{Text("Location").foregroundStyle(.secondary);Text(parent.path).lineLimit(1).font(.system(size:10));Spacer();Button("Choose…"){let p=NSOpenPanel();p.canChooseDirectories=true;p.canChooseFiles=false;if p.runModal()==.OK,let u=p.url{parent=u}}.buttonStyle(GlassButton())};HStack{if let image,let ns=NSImage(contentsOf:image){Image(nsImage:ns).resizable().scaledToFill().frame(width:68,height:52).clipShape(RoundedRectangle(cornerRadius:8))}else{Image(systemName:"photo").frame(width:68,height:52).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:8))};Button("Choose Thumbnail…"){let p=NSOpenPanel();p.allowedContentTypes=[.png,.jpeg,.heic,.tiff];if p.runModal()==.OK{image=p.url}}.buttonStyle(GlassButton());if image != nil{Button("Remove"){image=nil}.buttonStyle(.plain)}};Spacer();HStack{Spacer();Button("Cancel"){dismiss()}.buttonStyle(GlassButton());Button("Create Workspace"){store.create(name:name,parent:parent,kind:kind,image:image);if store.error==nil{dismiss()}}.buttonStyle(AccentButton()).disabled(name.trimmingCharacters(in:.whitespaces).isEmpty)}}.padding(24).frame(width:500,height:410).background(.regularMaterial).preferredColorScheme(.dark)}
}

struct GameCreationPage:View {
 @State private var selected="Overview"
 let sections:[(String,String,String)]=[
  ("Scenes","Build levels, arrange objects and manage scene hierarchies.","square.3.layers.3d"),
  ("Worlds","Create terrain, environments, towns, interiors and procedural worlds.","globe.americas.fill"),
  ("Characters","Design players, NPCs, enemies, rigs and character properties.","person.3.fill"),
  ("Game Logic","Create gameplay systems, interactions, physics rules and scripts.","function"),
  ("Animation","Work with skeletons, rigs, keyframes, blending and cutscenes.","figure.run"),
  ("Game UI","Build HUDs, menus, inventories, dialogue and interface layouts.","rectangle.on.rectangle"),
  ("Assets","Generate and organise 2D art, 3D models, textures and materials.","cube.transparent"),
  ("Audio","Create and manage sound effects, music, dialogue and ambience.","waveform"),
  ("VFX","Create particles, weather, shaders, lighting effects and visual polish.","sparkles"),
  ("Prompt Blocks","Compose reusable AI instructions and connect feature blocks.","square.grid.3x3"),
  ("AI Generation","Prepare, review and manage generation tasks for game content.","wand.and.stars"),
  ("Preview & Build","Preview gameplay, test scenes and prepare export builds.","play.rectangle")
 ]
 var body:some View {
  ScrollView {
   VStack(alignment:.leading,spacing:20) {
    VStack(alignment:.leading,spacing:5) {
     Text("Game Creation").font(.system(size:27,weight:.bold,design:.rounded))
     Text("Every tool for building your game, together in one workspace.").font(.system(size:12)).foregroundStyle(.secondary)
    }.padding(.top,28)
    ScrollView(.horizontal,showsIndicators:false) {
     HStack(spacing:8) {
      ForEach(["Overview","Scenes","Worlds","Characters","Game Logic","Animation","Game UI","Assets","Audio","VFX","Prompt Blocks","AI Generation","Preview & Build"],id:\\.self) { tab in
       Button { selected=tab } label: {
        Text(tab).font(.system(size:10,weight:.medium)).padding(.horizontal,12).padding(.vertical,8)
         .background(selected==tab ? .blue.opacity(0.28):.white.opacity(0.06),in:Capsule())
       }.buttonStyle(.plain)
      }
     }
    }
    if selected=="Overview" {
     LazyVGrid(columns:[GridItem(.adaptive(minimum:205),spacing:12)],spacing:12) {
      ForEach(sections,id:\\.0) { item in
       Button { selected=item.0 } label: {
        VStack(alignment:.leading,spacing:10) {
         Image(systemName:item.2).font(.system(size:20)).foregroundStyle(.cyan)
         Text(item.0).font(.system(size:13,weight:.semibold))
         Text(item.1).font(.system(size:10)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
         HStack { Spacer(); Text("Open").font(.system(size:9,weight:.semibold)); Image(systemName:"arrow.up.right").font(.system(size:9)) }.foregroundStyle(.blue)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(15).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(.white.opacity(0.08)))
       }.buttonStyle(.plain)
      }
     }
    } else if let item=sections.first(where:{$0.0==selected}) {
     VStack(alignment:.leading,spacing:12) {
      Label(item.0,systemImage:item.2).font(.system(size:19,weight:.semibold))
      Text(item.1).font(.system(size:12)).foregroundStyle(.secondary)
      Text("This tool is part of the unified Game Creation workspace. Its editor and generation pipeline will be implemented as connected KshonGCS modules.").font(.system(size:11)).padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12))
     }.padding(18).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:15))
    }
   }.padding(.horizontal,26).padding(.bottom,28)
  }
 }
}
struct CodeWorkspacePage:View {
 @EnvironmentObject var store:WorkspaceStore
 @State private var source=""
 @State private var language="KshonScript"
 @State private var status="Code is local to this KshonGCS workspace."
 @State private var filename="main.kshon"
 let languages=["KshonScript","Rust","C++","C","Python","JavaScript","Swift"]
 var body:some View {
  VStack(alignment:.leading,spacing:14) {
   VStack(alignment:.leading,spacing:5) {
    Text("Code").font(.system(size:26,weight:.bold,design:.rounded))
    Text("Write or paste your own code and keep it inside the active game workspace.").font(.system(size:11)).foregroundStyle(.secondary)
   }
   HStack {
    TextField("Filename",text:$filename).textFieldStyle(.roundedBorder).frame(maxWidth:220)
    Picker("Language",selection:$language){ForEach(languages,id:\\.self){Text($0).tag($0)}}.frame(width:160)
    Spacer()
    Button("Save to Project"){saveCode()}.buttonStyle(AccentButton()).disabled(store.active==nil || filename.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
   }
   TextEditor(text:$source).font(.system(size:12,design:.monospaced)).scrollContentBackground(.hidden).padding(10).background(Color.black.opacity(0.28),in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(.white.opacity(0.1)))
   HStack {
    Circle().fill(store.active == nil ? .orange:.green).frame(width:6,height:6)
    Text(store.active?.name ?? "No active project").font(.system(size:10)).foregroundStyle(.secondary)
    Spacer()
    Text(status).font(.system(size:10)).foregroundStyle(.secondary)
   }
   Text("CodePulse account linking and snippet import/export are intentionally not enabled yet.").font(.system(size:10)).foregroundStyle(.tertiary)
  }.padding(24)
 }
 private func saveCode() {
  guard let project=store.active else { status="Open a project workspace first."; return }
  let safeName=URL(fileURLWithPath:filename).lastPathComponent
  guard !safeName.isEmpty else { status="Enter a filename."; return }
  do {
   let folder=project.folder.appendingPathComponent("Scripts",isDirectory:true)
   try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
   try source.write(to:folder.appendingPathComponent(safeName),atomically:true,encoding:.utf8)
   status="Saved to Scripts/\(safeName)"
  } catch { status="Save failed: \(error.localizedDescription)" }
 }
}
\nstruct TutorialPage:View{
 @State var selected=0;@State var done:Set<Int>=[]
 let data:[(String,String,[String])]=[
 ("Your First 3D Scene","BEGINNER",["Create a 3D project","Open the Scene workspace","Add a camera","Add a cube","Run the scene preview"]),
 ("Build a Player Controller","BEGINNER",["Create a player entity","Add a transform","Configure movement input","Add collision","Test movement"]),
 ("Create a Health System","INTERMEDIATE",["Add a Health System prompt block","Set maximum health","Configure damage and regeneration","Connect a health HUD","Test damage and recovery"]),
 ("Import and Organise Assets","BEGINNER",["Open the Asset Library","Import a model or texture","Review the asset preview","Assign an asset category","Place the asset in your scene"])]
 var body:some View{HStack(spacing:0){VStack(alignment:.leading,spacing:12){Text("Gameplay Tutorials").font(.system(size:22,weight:.bold,design:.rounded));Text("Learn by building real game features.").font(.system(size:11)).foregroundStyle(.secondary);ForEach(data.indices,id:\.self){i in Button{selected=i;done=[]}label:{VStack(alignment:.leading,spacing:4){Text(data[i].0).font(.system(size:11,weight:.semibold));Text(data[i].1).font(.system(size:9)).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(selected==i ? .white.opacity(0.1):.clear,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain)};Spacer()}.padding(22).frame(width:250);Rectangle().fill(.white.opacity(0.08)).frame(width:1);ScrollView{VStack(alignment:.leading,spacing:18){Text(data[selected].1).font(.system(size:9,weight:.bold)).tracking(1).padding(8).background(.blue.opacity(0.18),in:Capsule());Text(data[selected].0).font(.system(size:26,weight:.bold,design:.rounded));Text("Follow these steps and mark each one as you complete it.").font(.system(size:12)).foregroundStyle(.secondary);ForEach(data[selected].2.indices,id:\.self){i in Button{if done.contains(i){done.remove(i)}else{done.insert(i)}}label:{Label(data[selected].2[i],systemImage:done.contains(i) ? "checkmark.circle.fill":"circle").font(.system(size:12)).foregroundStyle(done.contains(i) ? .green:.primary).frame(maxWidth:.infinity,alignment:.leading).padding(13).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain)};ProgressView(value:Double(done.count),total:Double(data[selected].2.count));Text("\(done.count) of \(data[selected].2.count) completed").font(.system(size:10)).foregroundStyle(.secondary)}.padding(28)}}}
}
struct GlassButton:ButtonStyle{func makeBody(configuration:Configuration)->some View{configuration.label.font(.system(size:10,weight:.medium)).padding(.horizontal,12).padding(.vertical,8).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(.white.opacity(0.12))).opacity(configuration.isPressed ? 0.65:1)}}
struct AccentButton:ButtonStyle{func makeBody(configuration:Configuration)->some View{configuration.label.font(.system(size:10,weight:.semibold)).padding(.horizontal,12).padding(.vertical,8).background(.blue.opacity(configuration.isPressed ? 0.55:0.85),in:RoundedRectangle(cornerRadius:9))}}
