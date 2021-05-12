package io.papermc.paper.brigadier;

import com.mojang.brigadier.Message;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.ComponentLike;
import net.kyori.adventure.text.TextComponent;
import org.checkerframework.checker.nullness.qual.NonNull;

/**
 * Helper methods to bridge the gaps between Brigadier and Paper-MojangAPI.
 */
public final class PaperBrigadier {
    private PaperBrigadier() {
        throw new RuntimeException("PaperBrigadier is not to be instantiated!");
    }

    /**
     * Create a new Brigadier {@link Message} from a {@link ComponentLike}.
     *
     * <p>Mostly useful for creating rich suggestion tooltips in combination with other Paper-MojangAPI APIs.</p>
     *
     * @param componentLike The {@link ComponentLike} to use for the {@link Message} contents
     * @return A new Brigadier {@link Message}
     */
    public static @NonNull Message message(final @NonNull ComponentLike componentLike) {
        return PaperBrigadierProvider.instance().message(componentLike);
    }

    /**
     * Create a new {@link Component} from a Brigadier {@link Message}.
     *
     * <p>If the {@link Message} was created from a {@link Component}, it will simply be
     * converted back, otherwise a new {@link TextComponent} will be created with the
     * content of {@link Message#getString()}</p>
     *
     * @param message The {@link Message} to create a {@link Component} from
     * @return The created {@link Component}
     */
    public static @NonNull Component componentFromMessage(final @NonNull Message message) {
        return PaperBrigadierProvider.instance().componentFromMessage(message);
    }
}
