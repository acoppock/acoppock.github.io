# Front-page art: galos_coppock_2023 figure 4 (maintained edition) without axes.
# Occupations for which the original authors made no prediction are gray.

library(tidyverse)

source_csv <- "~/Library/CloudStorage/Dropbox/active_maintenance_aec/remasters/galos_coppock_2023/maintained_output/figure_4_cates_gender_gradient.csv"

# Data ----

gg_df <-
  read_csv(source_csv, show_col_types = FALSE) |>
  filter(layer == "point") |>
  mutate(
    group = if_else(author_classification == "yes", occupation_gender_distribution, "no_prediction"),
    group = factor(group, levels = c("no_prediction", "men_dominated", "mixed", "women_dominated"))
  ) |>
  arrange(group)

# Plot ----

palette <- c(
  no_prediction = "#BDBDBD",
  men_dominated = "#CA3E56",
  mixed = "#E9CC61",
  women_dominated = "#91409A"
)

shapes <- c(no_prediction = 16, men_dominated = 16, mixed = 17, women_dominated = 15)

g <-
  ggplot(gg_df, aes(fraction_female, estimate, color = group, shape = group)) +
  geom_hline(yintercept = seq(-10, 10, 5), color = "gray92", linewidth = 0.6) +
  geom_linerange(aes(ymin = conf.low, ymax = conf.high), alpha = 0.25, linewidth = 0.8) +
  geom_point(aes(size = weight), alpha = 0.8, stroke = 0) +
  coord_cartesian(xlim = c(0, 1), ylim = c(-25, 25)) +
  scale_size_continuous(range = c(1, 5)) +
  scale_color_manual(values = palette) +
  scale_shape_manual(values = shapes) +
  theme_void() +
  theme(legend.position = "none", plot.background = element_rect(fill = NA, color = NA))

ggsave(here::here("images", "front_page.png"), plot = g, width = 6.5, height = 4, dpi = 300, bg = "transparent")

# Gallery card ----

# The build syncs cards from the catalog, so the card is written there as well as into the site.
card_paths <- c(
  "~/Library/CloudStorage/Dropbox/works/catalog/galos_coppock_2023/assets/galos_coppock_2023_card.png",
  here::here("card_figures", "galos_coppock_2023_card.png")
)

walk(card_paths, \(path) ggsave(path, plot = g, width = 5, height = 5, dpi = 200, bg = "white"))
