rm(list = ls())
setwd("~/git_projects/acoppock.github.io/")
library(magick)
library(magrittr)


# For logos

twitter <- image_read("images/twitterLogo.svg", density = 1000)
github <- image_read("images/gitHubLogo2.svg", density = 1000)
dataverse <- image_read("images/dataverseLogo.png")

dataverse %>% 
  image_convert(format = "svg") %>%
  image_write(path = "images/dataverseLogo.svg")



orcid <- image_read("images/orcidLogo.png")

orcid %>% 
  image_convert(format = "svg") %>%
  image_write(path = "images/orcidLogo.svg")


yale <- image_read("images/yaleLogo.png")

yale %>% 
  image_convert(format = "svg") %>%
  image_write(path = "images/yaleLogo.svg")



gscholar <- image_read("images/gscholarLogo.png")

gscholar %>% 
  image_convert(format = "svg") %>%
  image_write(path = "images/gscholarLogo.svg")



twitter





# For papers
files <- list.files(path = "papers/", pattern = ".pdf")
files <- files[files != "CG_habit.pdf"]

file_names <- gsub(pattern = ".pdf", replacement = "", x = files)

for(i in 1:length(files)){
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
  image_crop("400x400") %>%
  image_write("papers/CG_habit.png")

