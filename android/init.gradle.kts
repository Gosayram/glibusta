// Gradle init script — forces KGP on all subprojects before plugin buildscripts run
allprojects {
    buildscript {
        repositories {
            google()
            mavenCentral()
            gradlePluginPortal()
        }
        dependencies {
            classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.20")
        }
    }
}
