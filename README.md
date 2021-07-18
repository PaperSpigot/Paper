Paper ![GitHub Workflow Status (branch)](https://img.shields.io/github/workflow/status/PaperMC/Paper/Build%20Paper/master) ![Read the Docs (version)](https://img.shields.io/readthedocs/paper/latest) ![version](https://img.shields.io/badge/version-1.17.1-9fc) ![Sonatype Nexus (Query Options)](https://img.shields.io/nexus/maven-snapshots/io.papermc.paper/paper-api?label=repo&server=https%3A%2F%2Fpapermc.io%2Frepo) 
[![Discord](https://img.shields.io/discord/289587909051416579.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.gg/papermc)
===========

High performance Spigot fork that aims to fix gameplay and mechanics inconsistencies.


**Support and Project Discussion:**
 - [IRC](https://webchat.esper.net/?channels=paper) or [Discord](https://discord.gg/papermc)
 

How To (Server Admins)
------
Paperclip is a jar file that you can download and run just like a normal jar file.

Download Paper from our [downloads page](https://papermc.io/downloads).

Run the Paperclip jar directly from your server. Just like old times

  * Documentation on using Paper: [paper.readthedocs.io](https://paper.readthedocs.io/)
  * For a sneak peak on upcoming features, [see here](https://github.com/PaperMC/Paper/projects)

How To (Plugin Developers)
------
 * See our API patches [here](patches/api)
 * See upcoming, pending, and recently added API [here](https://github.com/PaperMC/Paper/projects/6)
 * Paper API javadocs here: [papermc.io/javadocs](https://papermc.io/javadocs/)
 * Maven Repo (for paper-api):
```xml
<repository>
    <id>papermc</id>
    <url>https://papermc.io/repo/repository/maven-public/</url>
</repository>
```
 * Artifact Information:
```xml
<dependency>
    <groupId>io.papermc.paper</groupId>
    <artifactId>paper-api</artifactId>
    <version>1.17.1-R0.1-SNAPSHOT</version>
    <scope>provided</scope>
</dependency>
 ```

**Or alternatively, with Gradle:**

```kotlin
repositories {
    maven {
        url = uri("https://papermc.io/repo/repository/maven-public/")
    }
}

dependencies {
    compileOnly("io.papermc.paper:paper-api:1.17.1-R0.1-SNAPSHOT")
}

configure<JavaPluginConvention> {
    // Additionally, you need to do either:

    // Require Java 16 (or newer) for compilation:
    sourceCompatibility = JavaVersion.VERSION_16
    targetCompatibility = sourceCompatibility

    // Or: stop requiring the dependencies to be at most your own Java version.
    // This will not work with Java N plugins using Java N+1 or above dependencies (e.g. Java 8 plugin + Java 16 API).
    // Note: This will NOT break the plugin; however, you will get errors if the API returns non-existent classes in earlier versions.
    disableAutoTargetJvm()
}
```

How To (Compiling Jar From Source)
------
To compile Paper, you need JDK 16 and an internet connection.

Clone this repo, run `./gradlew applyPatches`, then `./gradlew reobfJar` from your terminal. You can find the compiled jar in the `Paper-Server/build/libs` directory.

To get a full list of tasks, run `./gradlew tasks`.

How To (Pull Request)
------
See [Contributing](CONTRIBUTING.md)

Special Thanks To:
-------------

[![YourKit-Logo](https://www.yourkit.com/images/yklogo.png)](https://www.yourkit.com/)

[YourKit](https://www.yourkit.com/), makers of the outstanding java profiler, support open source projects of all kinds with their full featured [Java](https://www.yourkit.com/java/profiler) and [.NET](https://www.yourkit.com/.net/profiler) application profilers. We thank them for granting Paper an OSS license so that we can make our software the best it can be.

[<img src="https://user-images.githubusercontent.com/21148213/121807008-8ffc6700-cc52-11eb-96a7-2f6f260f8fda.png" alt="" width="150">](https://www.jetbrains.com)

[JetBrains](https://www.jetbrains.com/), creators of the IntelliJ IDEA, supports Paper with one of their [Open Source Licenses](https://www.jetbrains.com/opensource/). IntelliJ IDEA is the recommended IDE for working with Paper, and most of the Paper team uses it.

