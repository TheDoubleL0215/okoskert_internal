import com.android.build.gradle.LibraryExtension

plugins {
    id("com.android.library") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Olyan pub pluginok (pl. maps_launcher), amelyek régi compileSdk-t hardkódolnak, AAR metadata hibát okoznak.
subprojects {
    afterEvaluate {
        project.extensions.findByType(LibraryExtension::class.java)?.apply {
            compileSdk = 36
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
