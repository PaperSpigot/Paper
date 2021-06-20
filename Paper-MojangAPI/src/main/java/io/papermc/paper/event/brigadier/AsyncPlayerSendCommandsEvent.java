package io.papermc.paper.event.brigadier;

import io.papermc.paper.brigadier.BukkitBrigadierCommandSource;
import com.mojang.brigadier.tree.RootCommandNode;
import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.event.HandlerList;
import org.bukkit.event.player.PlayerEvent;
import org.jetbrains.annotations.NotNull;

/**
 * Fired any time a Brigadier RootCommandNode is generated for a player to inform the client of commands.
 * You may manipulate this CommandNode to change what the client sees.
 *
 * This event may fire on login, world change, and permission rebuilds, by plugin request, and potentially future means.
 *
 * This event will fire before {@link org.bukkit.event.player.PlayerCommandSendEvent}, so no filtering has been done by
 * other plugins yet.
 *
 * WARNING: This event will potentially (and most likely) fire twice! Once for Async, and once again for Sync.
 * It is important that you check event.isAsynchronous() and event.hasFiredAsync() to ensure you only act once.
 * If for some reason we are unable to send this asynchronously in the future, only the sync method will fire.
 *
 * Your logic should look like this:
 * if (event.isAsynchronous() || !event.hasFiredAsync()) { do stuff }
 *
 * If your logic is not safe to run asynchronously, only react to the synchronous version.
 * @deprecated Draft API - Subject to change until confirmed solves desired use cases
 */
public class AsyncPlayerSendCommandsEvent <S extends BukkitBrigadierCommandSource> extends PlayerEvent {

    private static final HandlerList handlers = new HandlerList();
    private final RootCommandNode<S> node;
    private final boolean hasFiredAsync;

    public AsyncPlayerSendCommandsEvent(Player player, RootCommandNode<S> node, boolean hasFiredAsync) {
        super(player, !Bukkit.isPrimaryThread());
        this.node = node;
        this.hasFiredAsync = hasFiredAsync;
    }

    /**
     * @return The full Root Command Node being sent to the client, which is mutable.
     */
    public RootCommandNode<S> getCommandNode() {
        return node;
    }

    /**
     * @return If this event has already fired asynchronously.
     */
    public boolean hasFiredAsync() {
        return hasFiredAsync;
    }

    @NotNull
    public HandlerList getHandlers() {
        return handlers;
    }

    @NotNull
    public static HandlerList getHandlerList() {
        return handlers;
    }
}
