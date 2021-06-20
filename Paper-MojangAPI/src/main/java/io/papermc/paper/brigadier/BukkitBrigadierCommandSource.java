package io.papermc.paper.brigadier;

import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Entity;
import org.jetbrains.annotations.Nullable;

public interface BukkitBrigadierCommandSource {

    @Nullable
    Entity getBukkitEntity();

    @Nullable
    World getBukkitWorld();

    @Nullable
    Location getBukkitLocation();

    CommandSender getBukkitSender();
}
