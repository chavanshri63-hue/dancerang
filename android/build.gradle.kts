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

// Workaround for third-party libraries missing AGP 8+ namespace declaration
subprojects {
    if (name == "qr_code_scanner") {
        afterEvaluate {
            val androidExt = extensions.findByName("android")
            // Set namespace from the library's manifest package
            try {
                @Suppress("UNCHECKED_CAST")
                val libExt = androidExt as? com.android.build.gradle.LibraryExtension
                if (libExt != null && libExt.namespace == null) {
                    libExt.namespace = "net.touchcapture.qr.flutterqr"
                }
            } catch (_: Throwable) {
                // no-op: best-effort to avoid build failure
            }

            // Align qr_code_scanner to Java 1.8 and Kotlin JVM 1.8 to match its sources
            tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
                sourceCompatibility = "1.8"
                targetCompatibility = "1.8"
            }
            tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                kotlinOptions.jvmTarget = "1.8"
            }
        }
    }
    // Align Java/Kotlin target compatibility across all subprojects to Java 17
    tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        kotlinOptions.jvmTarget = if (project.name == "fluttertoast") "11" else "17"
    }

    // Do not override Kotlin toolchain globally to avoid 'languageVersion is final' errors.
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
