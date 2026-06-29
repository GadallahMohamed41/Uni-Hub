allprojects {
    repositories {
        google()
        mavenCentral()
<<<<<<< HEAD
        // Flutter IO repository
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
        // Maven Central explicit HTTPS mirror
        maven {
            url = uri("https://repo1.maven.org/maven2/")
        }
        // JCenter (fallback for older packages like android-jsc)
        maven {
            url = uri("https://jcenter.bintray.com")
        }
    }

    // Force all subprojects to use HTTPS for Maven resolution
    configurations.all {
        resolutionStrategy {
            // Retry on failure
            cacheDynamicVersionsFor(5, "minutes")
            cacheChangingModulesFor(0, "seconds")
        }
=======
        jcenter()  // ✅ تم إضافة JCenter لحل مشكلة android-jsc
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
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