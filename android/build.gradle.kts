allprojects {
    repositories {
        // Syntaxe Kotlin DSL correcte pour les miroirs Aliyun
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
    }
}

// Récupération propre du chemin absolu du dossier de build principal
val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.set(newBuildDir)

// Configuration propre des sous-projets sans récursion
subprojects {
    val subprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Configuration corrigée pour injecter le namespace sans utiliser afterEvaluate
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.apply {
            if (namespace == null) {
                namespace = project.group.toString()
            }
        }
    }
    plugins.withId("com.android.application") {
        extensions.findByType(com.android.build.api.dsl.ApplicationExtension::class.java)?.apply {
            if (namespace == null) {
                namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}