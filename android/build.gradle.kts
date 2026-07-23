allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // whisper_ggml 2.4.0 still declares compileSdk 34 while its bundled
    // FFmpeg bridge requires API 35. Adjust only that plugin so unrelated
    // libraries retain their own SDK requirements.
    if (name == "whisper_ggml") {
        afterEvaluate {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 35
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
