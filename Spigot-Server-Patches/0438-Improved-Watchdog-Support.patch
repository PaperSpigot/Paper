From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001
From: Aikar <aikar@aikar.co>
Date: Sun, 12 Apr 2020 15:50:48 -0400
Subject: [PATCH] Improved Watchdog Support

Forced Watchdog Crash support and Improve Async Shutdown

If the request to shut down the server is received while we are in
a watchdog hang, immediately treat it as a crash and begin the shutdown
process. Shutdown process is now improved to also shutdown cleanly when
not using restart scripts either.

If a server is deadlocked, a server owner can send SIGUP (or any other signal
the JVM understands to shut down as it currently does) and the watchdog
will no longer need to wait until the full timeout, allowing you to trigger
a close process and try to shut the server down gracefully, saving player and
world data.

Previously there was no way to trigger this outside of waiting for a full watchdog
timeout, which may be set to a really long time...

Additionally, fix everything to do with shutting the server down asynchronously.

Previously, nearly everything about the process was fragile and unsafe. Main might
not have actually been frozen, and might still be manipulating state.

Or, some reuest might ask main to do something in the shutdown but main is dead.

Or worse, other things might start closing down items such as the Console or Thread Pool
before we are fully shutdown.

This change tries to resolve all of these issues by moving everything into the stop
method and guaranteeing only one thread is stopping the server.

We then issue Thread Death to the main thread of another thread initiates the stop process.
We have to ensure Thread Death propagates correctly though to stop main completely.

This is to ensure that if main isn't truely stuck, it's not manipulating state we are trying to save.

This also moves all plugins who register "delayed init" tasks to occur just before "Done" so they
are properly accounted for and wont trip watchdog on init.

diff --git a/src/main/java/com/destroystokyo/paper/Metrics.java b/src/main/java/com/destroystokyo/paper/Metrics.java
index 0b9e689d57705965721b5c55bc45d36657f360e4..dee00aac05f1acf050f05d4db557a08dd0f301c8 100644
--- a/src/main/java/com/destroystokyo/paper/Metrics.java
+++ b/src/main/java/com/destroystokyo/paper/Metrics.java
@@ -92,7 +92,12 @@ public class Metrics {
      * Starts the Scheduler which submits our data every 30 minutes.
      */
     private void startSubmitting() {
-        final Runnable submitTask = this::submitData;
+        final Runnable submitTask = () -> {
+            if (MinecraftServer.getServer().hasStopped()) {
+                return;
+            }
+            submitData();
+        };
 
         // Many servers tend to restart at a fixed time at xx:00 which causes an uneven distribution of requests on the
         // bStats backend. To circumvent this problem, we introduce some randomness into the initial and second delay.
diff --git a/src/main/java/net/minecraft/CrashReport.java b/src/main/java/net/minecraft/CrashReport.java
index d0fdb9ce57b22a1f582cddec9afcc35b75d58cc6..9b7a51890c667601b195ff15b2bf0d6c76c7f19f 100644
--- a/src/main/java/net/minecraft/CrashReport.java
+++ b/src/main/java/net/minecraft/CrashReport.java
@@ -257,6 +257,7 @@ public class CrashReport {
     }
 
     public static CrashReport a(Throwable throwable, String s) {
+        if (throwable instanceof ThreadDeath) com.destroystokyo.paper.util.SneakyThrow.sneaky(throwable); // Paper
         while (throwable instanceof CompletionException && throwable.getCause() != null) {
             throwable = throwable.getCause();
         }
diff --git a/src/main/java/net/minecraft/SystemUtils.java b/src/main/java/net/minecraft/SystemUtils.java
index 397194b3e90c9df39cfae17b401c7ac891b0dbb7..61b4c42e95994343772a91640b243b8e8224e09b 100644
--- a/src/main/java/net/minecraft/SystemUtils.java
+++ b/src/main/java/net/minecraft/SystemUtils.java
@@ -130,6 +130,7 @@ public class SystemUtils {
         return SystemUtils.f;
     }
 
+    public static void shutdownServerThreadPool() { h(); } // Paper - OBFHELPER
     public static void h() {
         a(SystemUtils.e);
         a(SystemUtils.f);
diff --git a/src/main/java/net/minecraft/server/MinecraftServer.java b/src/main/java/net/minecraft/server/MinecraftServer.java
index ed5712cc7c070f44500e5c1a1d41cd26bdd13fec..fe3fe04981a0cc1ddeac2e030ee754baae4e8409 100644
--- a/src/main/java/net/minecraft/server/MinecraftServer.java
+++ b/src/main/java/net/minecraft/server/MinecraftServer.java
@@ -270,7 +270,7 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
     public int autosavePeriod;
     public boolean serverAutoSave = false; // Paper
     public CommandDispatcher vanillaCommandDispatcher;
-    private boolean forceTicks;
+    public boolean forceTicks; // Paper
     // CraftBukkit end
     // Spigot start
     public static final int TPS = 20;
@@ -280,6 +280,8 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
     public final SlackActivityAccountant slackActivityAccountant = new SlackActivityAccountant();
     // Spigot end
 
+    public volatile Thread shutdownThread; // Paper
+
     public static <S extends MinecraftServer> S a(Function<Thread, S> function) {
         AtomicReference<S> atomicreference = new AtomicReference();
         Thread thread = new Thread(() -> {
@@ -842,6 +844,7 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
 
     // CraftBukkit start
     private boolean hasStopped = false;
+    public volatile boolean hasFullyShutdown = false; // Paper
     private final Object stopLock = new Object();
     public final boolean hasStopped() {
         synchronized (stopLock) {
@@ -856,6 +859,23 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
             if (hasStopped) return;
             hasStopped = true;
         }
+        // Paper start - kill main thread, and kill it hard
+        shutdownThread = Thread.currentThread();
+        org.spigotmc.WatchdogThread.doStop(); // Paper
+        if (!isMainThread()) {
+            MinecraftServer.LOGGER.info("Stopping main thread (Ignore any thread death message you see! - DO NOT REPORT THREAD DEATH TO PAPER)");
+            while (this.getThread().isAlive()) {
+                this.getThread().stop();
+                try {
+                    Thread.sleep(1);
+                } catch (InterruptedException e) {}
+            }
+            // We've just obliterated the main thread, this will prevent stop from dying when removing players
+            MinecraftServer.getServer().getWorlds().forEach(world -> {
+                world.tickingEntities = false;
+            });
+        }
+        // Paper end
         // CraftBukkit end
         MinecraftServer.LOGGER.info("Stopping server");
         MinecraftTimings.stopServer(); // Paper
@@ -921,7 +941,18 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
             this.getUserCache().b(false); // Paper
         }
         // Spigot end
+        // Paper start - move final shutdown items here
+        LOGGER.info("Flushing Chunk IO");
         com.destroystokyo.paper.io.PaperFileIOThread.Holder.INSTANCE.close(true, true); // Paper
+        LOGGER.info("Closing Thread Pool");
+        SystemUtils.shutdownServerThreadPool(); // Paper
+        LOGGER.info("Closing Server");
+        try {
+            net.minecrell.terminalconsole.TerminalConsoleAppender.close(); // Paper - Use TerminalConsoleAppender
+        } catch (Exception e) {
+        }
+        this.exit();
+        // Paper end
     }
 
     public String getServerIp() {
@@ -1014,6 +1045,7 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
 
     protected void w() {
         try {
+            long serverStartTime = SystemUtils.getMonotonicNanos(); // Paper
             if (this.init()) {
                 this.nextTick = SystemUtils.getMonotonicMillis();
                 this.serverPing.setMOTD(new ChatComponentText(this.motd));
@@ -1021,6 +1053,18 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
                 this.a(this.serverPing);
 
                 // Spigot start
+                // Paper start - move done tracking
+                LOGGER.info("Running delayed init tasks");
+                this.server.getScheduler().mainThreadHeartbeat(this.ticks); // run all 1 tick delay tasks during init,
+                // this is going to be the first thing the tick process does anyways, so move done and run it after
+                // everything is init before watchdog tick.
+                // anything at 3+ won't be caught here but also will trip watchdog....
+                // tasks are default scheduled at -1 + delay, and first tick will tick at 1
+                String doneTime = String.format(java.util.Locale.ROOT, "%.3fs", (double) (SystemUtils.getMonotonicNanos() - serverStartTime) / 1.0E9D);
+                LOGGER.info("Done ({})! For help, type \"help\"", doneTime);
+                // Paper end
+
+                org.spigotmc.WatchdogThread.tick(); // Paper
                 org.spigotmc.WatchdogThread.hasStarted = true; // Paper
                 Arrays.fill( recentTps, 20 );
                 long start = System.nanoTime(), curTime, tickSection = start; // Paper - Further improve server tick loop
@@ -1076,6 +1120,12 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
                 this.a((CrashReport) null);
             }
         } catch (Throwable throwable) {
+            // Paper start
+            if (throwable instanceof ThreadDeath) {
+                MinecraftServer.LOGGER.error("Main thread terminated by WatchDog due to hard crash", throwable);
+                return;
+            }
+            // Paper end
             MinecraftServer.LOGGER.error("Encountered an unexpected exception", throwable);
             // Spigot Start
             if ( throwable.getCause() != null )
@@ -1107,14 +1157,14 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
             } catch (Throwable throwable1) {
                 MinecraftServer.LOGGER.error("Exception stopping the server", throwable1);
             } finally {
-                org.spigotmc.WatchdogThread.doStop(); // Spigot
+                //org.spigotmc.WatchdogThread.doStop(); // Spigot // Paper - move into stop
                 // CraftBukkit start - Restore terminal to original settings
                 try {
-                    net.minecrell.terminalconsole.TerminalConsoleAppender.close(); // Paper - Use TerminalConsoleAppender
+                    //net.minecrell.terminalconsole.TerminalConsoleAppender.close(); // Paper - Move into stop
                 } catch (Exception ignored) {
                 }
                 // CraftBukkit end
-                this.exit();
+                //this.exit(); // Paper - moved into stop
             }
 
         }
@@ -1170,6 +1220,12 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
 
     @Override
     public TickTask postToMainThread(Runnable runnable) {
+        // Paper start - anything that does try to post to main during watchdog crash, run on watchdog
+        if (this.hasStopped && Thread.currentThread().equals(shutdownThread)) {
+            runnable.run();
+            runnable = () -> {};
+        }
+        // Paper end
         return new TickTask(this.ticks, runnable);
     }
 
@@ -1412,6 +1468,7 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
                 try {
                     crashreport = CrashReport.a(throwable, "Exception ticking world");
                 } catch (Throwable t) {
+                    if (throwable instanceof ThreadDeath) { throw (ThreadDeath)throwable; } // Paper
                     throw new RuntimeException("Error generating crash report", t);
                 }
                 // Spigot End
@@ -1869,7 +1926,8 @@ public abstract class MinecraftServer extends IAsyncTaskHandlerReentrant<TickTas
             this.resourcePackRepository.a(collection);
             this.saveData.a(a(this.resourcePackRepository));
             datapackresources.i();
-            this.getPlayerList().savePlayers();
+            if (Thread.currentThread() != this.serverThread) return; // Paper
+            //this.getPlayerList().savePlayers(); // Paper - we don't need to do this
             this.getPlayerList().reload();
             this.customFunctionData.a(this.dataPackResources.a());
             this.ak.a(this.dataPackResources.h());
diff --git a/src/main/java/net/minecraft/server/dedicated/DedicatedServer.java b/src/main/java/net/minecraft/server/dedicated/DedicatedServer.java
index 557f80accfa36b495c9a8cffdab2e248c1cbb514..ec1f36736d79d4054ad7ff4da4e3659f35c811d6 100644
--- a/src/main/java/net/minecraft/server/dedicated/DedicatedServer.java
+++ b/src/main/java/net/minecraft/server/dedicated/DedicatedServer.java
@@ -279,7 +279,7 @@ public class DedicatedServer extends MinecraftServer implements IMinecraftServer
             long j = SystemUtils.getMonotonicNanos() - i;
             String s = String.format(Locale.ROOT, "%.3fs", (double) j / 1.0E9D);
 
-            DedicatedServer.LOGGER.info("Done ({})! For help, type \"help\"", s);
+            //DedicatedServer.LOGGER.info("Done ({})! For help, type \"help\"", s); // Paper moved to after init
             if (dedicatedserverproperties.announcePlayerAchievements != null) {
                 ((GameRules.GameRuleBoolean) this.getGameRules().get(GameRules.ANNOUNCE_ADVANCEMENTS)).a(dedicatedserverproperties.announcePlayerAchievements, (MinecraftServer) this);
             }
@@ -407,6 +407,7 @@ public class DedicatedServer extends MinecraftServer implements IMinecraftServer
             //this.remoteStatusListener.b(); // Paper - don't wait for remote connections
         }
 
+        hasFullyShutdown = true; // Paper
         System.exit(0); // CraftBukkit
     }
 
@@ -740,7 +741,7 @@ public class DedicatedServer extends MinecraftServer implements IMinecraftServer
     @Override
     public void stop() {
         super.stop();
-        SystemUtils.h();
+        //SystemUtils.h(); // Paper - moved into super
     }
 
     @Override
diff --git a/src/main/java/net/minecraft/server/level/PlayerChunkMap.java b/src/main/java/net/minecraft/server/level/PlayerChunkMap.java
index 8050be2ed04fb0b8141f92595680407bba65dad5..bb9c6e9aeb1f30af01338476ba1dd618b14124d5 100644
--- a/src/main/java/net/minecraft/server/level/PlayerChunkMap.java
+++ b/src/main/java/net/minecraft/server/level/PlayerChunkMap.java
@@ -536,6 +536,7 @@ public class PlayerChunkMap extends IChunkLoader implements PlayerChunk.d {
             MutableBoolean mutableboolean = new MutableBoolean();
 
             do {
+                boolean isShuttingDown = world.getMinecraftServer().hasStopped(); // Paper
                 mutableboolean.setFalse();
                 list.stream().map((playerchunk) -> {
                     CompletableFuture completablefuture;
diff --git a/src/main/java/net/minecraft/server/level/WorldServer.java b/src/main/java/net/minecraft/server/level/WorldServer.java
index c69eef0d523fc75dce2c2606f3e447591c7cf6dc..da3614a4a59884e7cbc8758cfdad9698eb15424f 100644
--- a/src/main/java/net/minecraft/server/level/WorldServer.java
+++ b/src/main/java/net/minecraft/server/level/WorldServer.java
@@ -177,7 +177,7 @@ public class WorldServer extends World implements GeneratorAccessSeed {
     private final Queue<Entity> entitiesToAdd = Queues.newArrayDeque();
     public final List<EntityPlayer> players = Lists.newArrayList(); // Paper - private -> public
     public final ChunkProviderServer chunkProvider; // Paper - public
-    boolean tickingEntities;
+    public boolean tickingEntities; // Paper - expose for watchdog
     // Paper start
     List<java.lang.Runnable> afterEntityTickingTasks = Lists.newArrayList();
     public void doIfNotEntityTicking(java.lang.Runnable run) {
diff --git a/src/main/java/net/minecraft/server/players/PlayerList.java b/src/main/java/net/minecraft/server/players/PlayerList.java
index f35825d4a8574ea75b46be36b9929f8e12405217..48d4f8310d79d0eb78f4ace42c8778ee4addf7d0 100644
--- a/src/main/java/net/minecraft/server/players/PlayerList.java
+++ b/src/main/java/net/minecraft/server/players/PlayerList.java
@@ -507,7 +507,7 @@ public abstract class PlayerList {
         cserver.getPluginManager().callEvent(playerQuitEvent);
         entityplayer.getBukkitEntity().disconnect(playerQuitEvent.getQuitMessage());
 
-        entityplayer.playerTick(); // SPIGOT-924
+        if (server.isMainThread()) entityplayer.playerTick(); // SPIGOT-924 // Paper - don't tick during emergency shutdowns (Watchdog)
         // CraftBukkit end
 
         // Paper start - Remove from collideRule team if needed
diff --git a/src/main/java/net/minecraft/util/thread/IAsyncTaskHandler.java b/src/main/java/net/minecraft/util/thread/IAsyncTaskHandler.java
index ca23ca14d8011fc8daa7e20f2eaa550a8ff92c53..158ea6d77698d62ba795aff6c061a80652e42e03 100644
--- a/src/main/java/net/minecraft/util/thread/IAsyncTaskHandler.java
+++ b/src/main/java/net/minecraft/util/thread/IAsyncTaskHandler.java
@@ -135,6 +135,7 @@ public abstract class IAsyncTaskHandler<R extends Runnable> implements Mailbox<R
         try {
             r0.run();
         } catch (Exception exception) {
+            if (exception.getCause() instanceof ThreadDeath) throw exception; // Paper
             IAsyncTaskHandler.LOGGER.fatal("Error executing task on {}", this.bj(), exception);
         }
 
diff --git a/src/main/java/net/minecraft/world/level/World.java b/src/main/java/net/minecraft/world/level/World.java
index cc41dcd85760b57bb8076b37e9a907d1cb4e12c7..efcfc8f0f45901d14ac8fdf8ed7b0bd67f8f94da 100644
--- a/src/main/java/net/minecraft/world/level/World.java
+++ b/src/main/java/net/minecraft/world/level/World.java
@@ -858,6 +858,7 @@ public abstract class World implements GeneratorAccess, AutoCloseable {
 
                         gameprofilerfiller.exit();
                     } catch (Throwable throwable) {
+                        if (throwable instanceof ThreadDeath) throw throwable; // Paper
                         // Paper start - Prevent tile entity and entity crashes
                         String msg = "TileEntity threw exception at " + tileentity.getWorld().getWorld().getName() + ":" + tileentity.getPosition().getX() + "," + tileentity.getPosition().getY() + "," + tileentity.getPosition().getZ();
                         System.err.println(msg);
@@ -932,6 +933,7 @@ public abstract class World implements GeneratorAccess, AutoCloseable {
         try {
             consumer.accept(entity);
         } catch (Throwable throwable) {
+            if (throwable instanceof ThreadDeath) throw throwable; // Paper
             // Paper start - Prevent tile entity and entity crashes
             String msg = "Entity threw exception at " + entity.world.getWorld().getName() + ":" + entity.locX() + "," + entity.locY() + "," + entity.locZ();
             System.err.println(msg);
diff --git a/src/main/java/org/bukkit/craftbukkit/CraftServer.java b/src/main/java/org/bukkit/craftbukkit/CraftServer.java
index 4828d356ca01cba5964c6397584d56643dbc0dae..55890ff463eb122934e8ba1fc550cf0cccaf8451 100644
--- a/src/main/java/org/bukkit/craftbukkit/CraftServer.java
+++ b/src/main/java/org/bukkit/craftbukkit/CraftServer.java
@@ -1834,7 +1834,7 @@ public final class CraftServer implements Server {
 
     @Override
     public boolean isPrimaryThread() {
-        return Thread.currentThread().equals(console.serverThread); // Paper - Fix issues with detecting main thread properly
+        return Thread.currentThread().equals(console.serverThread) || Thread.currentThread().equals(net.minecraft.server.MinecraftServer.getServer().shutdownThread); // Paper - Fix issues with detecting main thread properly, the only time Watchdog will be used is during a crash shutdown which is a "try our best" scenario
     }
 
     // Paper start
diff --git a/src/main/java/org/bukkit/craftbukkit/Main.java b/src/main/java/org/bukkit/craftbukkit/Main.java
index 67331fa5463dd31e4aea3aebf6204ec5cb43d99e..c0c08a9a4c6b44f3c1f79c8e4635472ef9c7dc99 100644
--- a/src/main/java/org/bukkit/craftbukkit/Main.java
+++ b/src/main/java/org/bukkit/craftbukkit/Main.java
@@ -12,6 +12,8 @@ import java.util.logging.Level;
 import java.util.logging.Logger;
 import joptsimple.OptionParser;
 import joptsimple.OptionSet;
+import net.minecraft.util.ExceptionSuppressor;
+import net.minecraft.world.level.lighting.LightEngineLayerEventListener;
 import net.minecrell.terminalconsole.TerminalConsoleAppender; // Paper
 
 public class Main {
@@ -150,6 +152,37 @@ public class Main {
 
         OptionSet options = null;
 
+        // Paper start - preload logger classes to avoid plugins mixing versions
+        tryPreloadClass("com.destroystokyo.paper.log.LogFullPolicy");
+        tryPreloadClass("org.apache.logging.log4j.core.Core");
+        tryPreloadClass("org.apache.logging.log4j.core.Appender");
+        tryPreloadClass("org.apache.logging.log4j.core.ContextDataInjector");
+        tryPreloadClass("org.apache.logging.log4j.core.Filter");
+        tryPreloadClass("org.apache.logging.log4j.core.ErrorHandler");
+        tryPreloadClass("org.apache.logging.log4j.core.LogEvent");
+        tryPreloadClass("org.apache.logging.log4j.core.Logger");
+        tryPreloadClass("org.apache.logging.log4j.core.LoggerContext");
+        tryPreloadClass("org.apache.logging.log4j.core.LogEventListener");
+        tryPreloadClass("org.apache.logging.log4j.core.AbstractLogEvent");
+        tryPreloadClass("org.apache.logging.log4j.message.AsynchronouslyFormattable");
+        tryPreloadClass("org.apache.logging.log4j.message.FormattedMessage");
+        tryPreloadClass("org.apache.logging.log4j.message.ParameterizedMessage");
+        tryPreloadClass("org.apache.logging.log4j.message.Message");
+        tryPreloadClass("org.apache.logging.log4j.message.MessageFactory");
+        tryPreloadClass("org.apache.logging.log4j.message.TimestampMessage");
+        tryPreloadClass("org.apache.logging.log4j.message.SimpleMessage");
+        tryPreloadClass("org.apache.logging.log4j.core.async.AsyncLogger");
+        tryPreloadClass("org.apache.logging.log4j.core.async.AsyncLoggerContext");
+        tryPreloadClass("org.apache.logging.log4j.core.async.AsyncQueueFullPolicy");
+        tryPreloadClass("org.apache.logging.log4j.core.async.AsyncLoggerDisruptor");
+        tryPreloadClass("org.apache.logging.log4j.core.async.RingBufferLogEvent");
+        tryPreloadClass("org.apache.logging.log4j.core.async.DisruptorUtil");
+        tryPreloadClass("org.apache.logging.log4j.core.async.RingBufferLogEventHandler");
+        tryPreloadClass("org.apache.logging.log4j.core.impl.ThrowableProxy");
+        tryPreloadClass("org.apache.logging.log4j.core.impl.ThrowableProxy$CacheEntry");
+        tryPreloadClass("org.apache.logging.log4j.core.impl.ExtendedClassInfo");
+        tryPreloadClass("org.apache.logging.log4j.core.impl.ExtendedStackTraceElement");
+        // Paper end
         try {
             options = parser.parse(args);
         } catch (joptsimple.OptionException ex) {
@@ -245,8 +278,64 @@ public class Main {
             } catch (Throwable t) {
                 t.printStackTrace();
             }
+            // Paper start
+            // load some required classes to avoid errors during shutdown if jar is replaced
+            // also to guarantee our version loads over plugins
+            tryPreloadClass("com.destroystokyo.paper.util.SneakyThrow");
+            tryPreloadClass("com.google.common.collect.Iterators$PeekingImpl");
+            tryPreloadClass("com.google.common.collect.MapMakerInternalMap$Values");
+            tryPreloadClass("com.google.common.collect.MapMakerInternalMap$ValueIterator");
+            tryPreloadClass("com.google.common.collect.MapMakerInternalMap$WriteThroughEntry");
+            tryPreloadClass("com.google.common.collect.Iterables");
+            for (int i = 1; i <= 15; i++) {
+                tryPreloadClass("com.google.common.collect.Iterables$" + i, false);
+            }
+            tryPreloadClass("org.apache.commons.lang3.mutable.MutableBoolean");
+            tryPreloadClass("org.apache.commons.lang3.mutable.MutableInt");
+            tryPreloadClass("org.jline.terminal.impl.MouseSupport");
+            tryPreloadClass("org.jline.terminal.impl.MouseSupport$1");
+            tryPreloadClass("org.jline.terminal.Terminal$MouseTracking");
+            tryPreloadClass("co.aikar.timings.TimingHistory");
+            tryPreloadClass("co.aikar.timings.TimingHistory$MinuteReport");
+            tryPreloadClass("io.netty.channel.AbstractChannelHandlerContext");
+            tryPreloadClass("io.netty.channel.AbstractChannelHandlerContext$11");
+            tryPreloadClass("io.netty.channel.AbstractChannelHandlerContext$12");
+            tryPreloadClass("io.netty.channel.AbstractChannel$AbstractUnsafe$8");
+            tryPreloadClass("io.netty.util.concurrent.DefaultPromise");
+            tryPreloadClass("io.netty.util.concurrent.DefaultPromise$1");
+            tryPreloadClass("io.netty.util.internal.PromiseNotificationUtil");
+            tryPreloadClass("io.netty.util.internal.SystemPropertyUtil");
+            tryPreloadClass("org.bukkit.craftbukkit.scheduler.CraftScheduler");
+            tryPreloadClass("org.bukkit.craftbukkit.scheduler.CraftScheduler$1");
+            tryPreloadClass("org.bukkit.craftbukkit.scheduler.CraftScheduler$2");
+            tryPreloadClass("org.bukkit.craftbukkit.scheduler.CraftScheduler$3");
+            tryPreloadClass("org.bukkit.craftbukkit.scheduler.CraftScheduler$4");
+            tryPreloadClass("org.slf4j.helpers.MessageFormatter");
+            tryPreloadClass("org.slf4j.helpers.FormattingTuple");
+            tryPreloadClass("org.slf4j.helpers.BasicMarker");
+            tryPreloadClass("org.slf4j.helpers.Util");
+            tryPreloadClass("com.destroystokyo.paper.event.player.PlayerConnectionCloseEvent");
+            tryPreloadClass("com.destroystokyo.paper.event.entity.EntityRemoveFromWorldEvent");
+            // Minecraft, seen during saving
+            tryPreloadClass(LightEngineLayerEventListener.Void.class.getName());
+            tryPreloadClass(LightEngineLayerEventListener.class.getName());
+            tryPreloadClass(ExceptionSuppressor.class.getName());
+            // Paper end
+        }
+    }
+
+    // Paper start
+    private static void tryPreloadClass(String className) {
+        tryPreloadClass(className, true);
+    }
+    private static void tryPreloadClass(String className, boolean printError) {
+        try {
+            Class.forName(className);
+        } catch (ClassNotFoundException e) {
+            if (printError) System.err.println("An expected class  " + className + " was not found for preloading: " + e.getMessage());
         }
     }
+    // Paper end
 
     private static List<String> asList(String... params) {
         return Arrays.asList(params);
diff --git a/src/main/java/org/bukkit/craftbukkit/util/ServerShutdownThread.java b/src/main/java/org/bukkit/craftbukkit/util/ServerShutdownThread.java
index 449e99d1b673870ed6892f6ab2c715a2db35c35d..c7ed6e0f8a989cec97700df2b15198c9c481c549 100644
--- a/src/main/java/org/bukkit/craftbukkit/util/ServerShutdownThread.java
+++ b/src/main/java/org/bukkit/craftbukkit/util/ServerShutdownThread.java
@@ -12,12 +12,27 @@ public class ServerShutdownThread extends Thread {
     @Override
     public void run() {
         try {
+            // Paper start - try to shutdown on main
+            server.safeShutdown(false, false);
+            for (int i = 1000; i > 0 && !server.hasStopped(); i -= 100) {
+                Thread.sleep(100);
+            }
+            if (server.hasStopped()) {
+                while (!server.hasFullyShutdown) Thread.sleep(1000);
+                return;
+            }
+            // Looks stalled, close async
             org.spigotmc.AsyncCatcher.enabled = false; // Spigot
             org.spigotmc.AsyncCatcher.shuttingDown = true; // Paper
+            server.forceTicks = true;
             server.close();
+            while (!server.hasFullyShutdown) Thread.sleep(1000);
+        } catch (InterruptedException e) {
+            e.printStackTrace();
+            // Paper end
         } finally {
             try {
-                net.minecrell.terminalconsole.TerminalConsoleAppender.close(); // Paper - Use TerminalConsoleAppender
+                //net.minecrell.terminalconsole.TerminalConsoleAppender.close(); // Paper - Move into stop
             } catch (Exception e) {
             }
         }
diff --git a/src/main/java/org/spigotmc/RestartCommand.java b/src/main/java/org/spigotmc/RestartCommand.java
index b45d7e5c108c7a8541fcbc9ad92d1a79a94746a1..6a408dc9286a60c3ca7830f88171919fb0fe6363 100644
--- a/src/main/java/org/spigotmc/RestartCommand.java
+++ b/src/main/java/org/spigotmc/RestartCommand.java
@@ -139,7 +139,7 @@ public class RestartCommand extends Command
     // Paper end
 
     // Paper start - copied from above and modified to return if the hook registered
-    private static boolean addShutdownHook(String restartScript)
+    public static boolean addShutdownHook(String restartScript)
     {
         String[] split = restartScript.split( " " );
         if ( split.length > 0 && new File( split[0] ).isFile() )
diff --git a/src/main/java/org/spigotmc/WatchdogThread.java b/src/main/java/org/spigotmc/WatchdogThread.java
index 58e50bf0fb0f309227e1f4c1f6bb11c01d8e08d3..30a665c090f419985e1d0f49df9e8d110c83943a 100644
--- a/src/main/java/org/spigotmc/WatchdogThread.java
+++ b/src/main/java/org/spigotmc/WatchdogThread.java
@@ -13,6 +13,7 @@ import org.bukkit.Bukkit;
 public class WatchdogThread extends Thread
 {
 
+    public static final boolean DISABLE_WATCHDOG = Boolean.getBoolean("disable.watchdog"); // Paper
     private static WatchdogThread instance;
     private long timeoutTime;
     private boolean restart;
@@ -41,6 +42,7 @@ public class WatchdogThread extends Thread
     {
         if ( instance == null )
         {
+            if (timeoutTime <= 0) timeoutTime = 300; // Paper
             instance = new WatchdogThread( timeoutTime * 1000L, restart );
             instance.start();
         } else
@@ -71,12 +73,13 @@ public class WatchdogThread extends Thread
             // Paper start
             Logger log = Bukkit.getServer().getLogger();
             long currentTime = monotonicMillis();
-            if ( lastTick != 0 && timeoutTime > 0 && currentTime > lastTick + earlyWarningEvery && !Boolean.getBoolean("disable.watchdog") )
+            MinecraftServer server = MinecraftServer.getServer();
+            if (lastTick != 0 && timeoutTime > 0 && hasStarted && (!server.isRunning() || (currentTime > lastTick + earlyWarningEvery && !DISABLE_WATCHDOG) ))
             {
-                boolean isLongTimeout = currentTime > lastTick + timeoutTime;
+                boolean isLongTimeout = currentTime > lastTick + timeoutTime || (!server.isRunning() && !server.hasStopped() && currentTime > lastTick + 1000);
                 // Don't spam early warning dumps
                 if ( !isLongTimeout && (earlyWarningEvery <= 0 || !hasStarted || currentTime < lastEarlyWarning + earlyWarningEvery || currentTime < lastTick + earlyWarningDelay)) continue;
-                if ( !isLongTimeout && MinecraftServer.getServer().hasStopped()) continue; // Don't spam early watchdog warnings during shutdown, we'll come back to this...
+                if ( !isLongTimeout && server.hasStopped()) continue; // Don't spam early watchdog warnings during shutdown, we'll come back to this...
                 lastEarlyWarning = currentTime;
                 if (isLongTimeout) {
                 // Paper end
@@ -118,7 +121,7 @@ public class WatchdogThread extends Thread
                 log.log( Level.SEVERE, "------------------------------" );
                 log.log( Level.SEVERE, "Server thread dump (Look for plugins here before reporting to Paper!):" ); // Paper
                 ChunkTaskManager.dumpAllChunkLoadInfo(); // Paper
-                dumpThread( ManagementFactory.getThreadMXBean().getThreadInfo( MinecraftServer.getServer().serverThread.getId(), Integer.MAX_VALUE ), log );
+                dumpThread( ManagementFactory.getThreadMXBean().getThreadInfo( server.serverThread.getId(), Integer.MAX_VALUE ), log );
                 log.log( Level.SEVERE, "------------------------------" );
                 //
                 // Paper start - Only print full dump on long timeouts
@@ -139,9 +142,24 @@ public class WatchdogThread extends Thread
 
                 if ( isLongTimeout )
                 {
-                if ( restart && !MinecraftServer.getServer().hasStopped() )
+                if ( !server.hasStopped() )
                 {
-                    RestartCommand.restart();
+                    AsyncCatcher.enabled = false; // Disable async catcher incase it interferes with us
+                    AsyncCatcher.shuttingDown = true;
+                    server.forceTicks = true;
+                    if (restart) {
+                        RestartCommand.addShutdownHook( SpigotConfig.restartScript );
+                    }
+                    // try one last chance to safe shutdown on main incase it 'comes back'
+                    server.safeShutdown(false, restart);
+                    try {
+                        Thread.sleep(1000);
+                    } catch (InterruptedException e) {
+                        e.printStackTrace();
+                    }
+                    if (!server.hasStopped()) {
+                        server.close();
+                    }
                 }
                 break;
                 } // Paper end
diff --git a/src/main/resources/log4j2.xml b/src/main/resources/log4j2.xml
index 476f4a5cbe664ddd05474cb88553018bd334a5b8..8af159abd3d0cc94cf155fec5b384c42f69551bf 100644
--- a/src/main/resources/log4j2.xml
+++ b/src/main/resources/log4j2.xml
@@ -1,5 +1,5 @@
 <?xml version="1.0" encoding="UTF-8"?>
-<Configuration status="WARN" packages="com.mojang.util">
+<Configuration status="WARN" packages="com.mojang.util" shutdownHook="disable">
     <Appenders>
         <Queue name="ServerGuiConsole">
             <PatternLayout pattern="[%d{HH:mm:ss} %level]: %msg%n" />
