allprojects {
    repositories {
        google()
        mavenCentral()
        jcenter()  // ✅ تم إضافة JCenter لحل مشكلة android-jsc
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

// Use default build directories for external plugins to avoid cross-drive issues on Windows.
// If you want to relocate build output, do it only for the :app module.
val relocatedRoot: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(relocatedRoot)

subprojects {
    if (project.name == "app") {
        val newSubprojectBuildDir: Directory = relocatedRoot.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}