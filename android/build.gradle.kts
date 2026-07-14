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
    project.evaluationDependsOn(":app")
}

// Auto-add namespace from AndroidManifest.xml for library plugins that miss it (AGP 9+).
// Required by transitive deps like irondash_engine_context 0.1.1.
subprojects {
    plugins.withId("com.android.library") {
        (extensions.findByName("android") as? com.android.build.api.dsl.LibraryExtension)?.let { android ->
            if (android.namespace == null) {
                val manifestFile = project.projectDir.resolve("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val text = manifestFile.readText()
                    val pkg = Regex("""package\s*=\s*"([^"]+)"""").find(text)?.groupValues?.getOrNull(1)
                    if (pkg != null) {
                        android.namespace = pkg
                    }
                }
            }
        }
    }
}

// Force consistent JVM target across all subprojects (plugins like
// receive_sharing_intent apply their own KGP with a different target).
gradle.projectsEvaluated {
    subprojects {
        if (name != "patrol") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
                }
            }
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "21"
                targetCompatibility = "21"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
