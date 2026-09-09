plugins {
    id("com.google.gms.google-services") apply false
    id("com.google.firebase.crashlytics") apply false
}

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
}

subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val namespaceGetter =
            androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
        val currentNamespace = namespaceGetter?.invoke(androidExt) as? String
        if (currentNamespace.isNullOrBlank()) {
            val manifest = file("src/main/AndroidManifest.xml")
            val pkg =
                if (manifest.exists()) {
                    Regex("""package="([^"]+)"""")
                        .find(manifest.readText())
                        ?.groupValues
                        ?.getOrNull(1)
                } else {
                    null
                }
            if (!pkg.isNullOrBlank()) {
                androidExt.javaClass.methods
                    .firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
                    ?.invoke(androidExt, pkg)
            }
        }
        val compileSdkSetter =
            androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterCount == 1
            }
        compileSdkSetter?.invoke(androidExt, 37)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
