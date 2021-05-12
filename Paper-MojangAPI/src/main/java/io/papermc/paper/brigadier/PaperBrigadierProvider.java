package io.papermc.paper.brigadier;

import com.mojang.brigadier.Message;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.ComponentLike;
import org.checkerframework.checker.nullness.qual.MonotonicNonNull;
import org.checkerframework.checker.nullness.qual.NonNull;

import static java.util.Objects.requireNonNull;

interface PaperBrigadierProvider {
    final class Holder {
        private static @MonotonicNonNull PaperBrigadierProvider INSTANCE;
    }

    static @NonNull PaperBrigadierProvider instance() {
        return requireNonNull(Holder.INSTANCE, "PaperBrigadierProvider has not yet been initialized!");
    }

    static void initialize(final @NonNull PaperBrigadierProvider instance) {
        if (Holder.INSTANCE != null) {
            throw new IllegalStateException("PaperBrigadierProvider has already been initialized!");
        }
        Holder.INSTANCE = instance;
    }

    @NonNull Message message(@NonNull ComponentLike componentLike);

    @NonNull Component componentFromMessage(@NonNull Message message);
}
