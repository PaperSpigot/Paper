package io.papermc.paper.event.brigadier;

import io.papermc.paper.brigadier.BukkitBrigadierCommand;
import io.papermc.paper.brigadier.BukkitBrigadierCommandSource;
import com.mojang.brigadier.tree.ArgumentCommandNode;
import com.mojang.brigadier.tree.LiteralCommandNode;
import com.mojang.brigadier.tree.RootCommandNode;
import org.bukkit.command.Command;
import org.bukkit.event.Cancellable;
import org.bukkit.event.HandlerList;
import org.bukkit.event.server.ServerEvent;
import org.jetbrains.annotations.NotNull;

/**
 * Fired anytime the server synchronizes Bukkit CommandMap to Brigadier.
 *
 * Allows a plugin to control the Literal and Argument nodes for this command to be
 * sent to the client.
 * This is done at Plugin Enable time after commands have been registered, but some
 * plugins may use reflection to retrigger this rebuild during runtime.
 *
 * @deprecated Draft API - Subject to change until confirmed solves desired use cases
 */
public class CommandRegisteredEvent <S extends BukkitBrigadierCommandSource> extends ServerEvent implements Cancellable {

    private static final HandlerList handlers = new HandlerList();
    private final String commandLabel;
    private final Command command;
    private final BukkitBrigadierCommand<S> brigadierCommand;
    private final RootCommandNode<S> root;
    private final ArgumentCommandNode<S, String> defaultArgs;
    private LiteralCommandNode<S> literal;
    private boolean cancelled = false;

    public CommandRegisteredEvent(String commandLabel, BukkitBrigadierCommand<S> brigadierCommand, Command command, RootCommandNode<S> root, LiteralCommandNode<S> literal, ArgumentCommandNode<S, String> defaultArgs) {
        this.commandLabel = commandLabel;
        this.brigadierCommand = brigadierCommand;
        this.command = command;
        this.root = root;
        this.literal = literal;
        this.defaultArgs = defaultArgs;
    }

    /**
     * @return The command name being registered
     */
    public String getCommandLabel() {
        return commandLabel;
    }

    /**
     * @return The Bukkit API Brigadier Wrapped Command Object to handle executions and suggestions
     */
    public BukkitBrigadierCommand<S> getBrigadierCommand() {
        return brigadierCommand;
    }

    public Command getCommand() {
        return command;
    }

    /**
     * @return Gets the root command node being used to register a command to.
     */
    public RootCommandNode<S> getRoot() {
        return root;
    }

    /**
     * Returns the Bukkit API's default handling of Arguments, if you wish to reuse it.
     * @return
     */
    public ArgumentCommandNode<S, String> getDefaultArgs() {
        return defaultArgs;
    }

    /**
     * Returns the Bukkit API's default literal for this command, including the {@link #getDefaultArgs()} as a child already.
     * @return
     */
    public LiteralCommandNode<S> getLiteral() {
        return literal;
    }

    /**
     * Changes the literal used to register this command. The previous literable is mutable, so this is primarily if
     * you want to completely replace the object.
     * @param literal
     */
    public void setLiteral(LiteralCommandNode<S> literal) {
        this.literal = literal;
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public boolean isCancelled() {
        return this.cancelled;
    }

    /**
     * Cancels registering this command to Brigadier, but will remain in Bukkit Command Map. Can be used to hide a
     * command from all players.
     *
     * {@inheritDoc}
     */
    @Override
    public void setCancelled(boolean cancel) {
        this.cancelled = cancel;
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
