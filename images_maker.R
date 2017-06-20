rm(list = ls())
setwd("~/git_projects/acoppock.github.io/")
library(magick)
library(magrittr)

# For papers
files <- list.files(path = "papers/", pattern = ".pdf")
files <- files[files != "CG_habit.pdf"]

file_names <- gsub(pattern = ".pdf",
                   replacement = "",
                   x = files)

for (i in 1:length(files)) {
  image_read(paste0("papers/", files[i], "[0]"), density = 500) %>%
    image_scale("1000") %>%
    image_crop("1000x1000") %>%
    image_convert(format = "png") %>%
    image_write(paste0("papers/", file_names[i], ".png"))
  print(i)
}

# Fix habit
image_read("papers/CG_habit_test_Page_01.png") %>%
  image_scale("1000") %>%
  image_crop("1000x1000") %>%
  image_write("papers/CG_habit.png")


# For logos

# image_read("images/dataverseLogo.png") %>%
#   image_convert(format = "svg") %>%
#   image_write(path = "images/dataverseLogo.svg")
# 
# image_read("images/orcidLogo.png") %>%
#   image_convert(format = "svg") %>%
#   image_write(path = "images/orcidLogo.svg")
# 
# image_read("images/yaleLogo.png") %>%
#   image_convert(format = "svg") %>%
#   image_write(path = "images/yaleLogo.svg")
# 
# image_read("images/gscholarLogo.png") %>%
#   image_convert(format = "svg") %>%
#   image_write(path = "images/gscholarLogo.svg")
