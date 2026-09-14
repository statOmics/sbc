# Add the following lines to _output.yml
"
bookdown::markdown_document2:
  base_format: rmarkdown::md_document
variant: gfm
"


packages = c("tidyverse",
             "Rfast",
             "mvtnorm",
             "yaml",
             "jsonlite",
             "GGally",
             "multcomp",
             "plotrix",
             "formatR",
             "plot3D")


## Load and install if necessary
package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!x %in% rownames(installed.packages())) {
      install.packages(x, dependencies = TRUE)
    }
  }
)

library(dplyr)
library(stringr)
library(yaml)
library(jsonlite)

# REGEX Patterns used to convert gfm syntax to kramdown (the format used in dodona)

title_pattern <- "^(#+)[[:space:]]+(\\S.*)$"
code_pattern <- "^\\s*```"
# regex pattern for html image tags
image_pattern_html <- "<img src=\"([^\"]+)\""
# regex pattern for markdown image tags, avoiding urls
image_pattern_md <- "!\\[\\]\\((?!http)([^\\(\\)]+)\\)"
image_pattern_url <- "!\\[\\]\\((?=http)([^\\(\\)]+)\\)"
table_pattern <- "<table[^>]*>"
href_pattern <- "<a href=[^>]+>([[[:digit:]]\\.]+)</a>"
mdref_pattern <- "\\\\\\[[[:digit:]]+\\\\\\]"
math_pattern <- "\\\\\\(|\\\\\\)|\\\\\\[|\\\\\\]"
noNum_pattern <- "<!---noNum-->"
break_pattern <- "<!---break-->"

######## THESE PARAMETERS CAN BE CHANGED BY THE USER ##########
image_folder <- 'media'
continue_str <- 'Vervolg'
###############################################################

render_to_dodona_md <- function(input, book_dir = 'book_md', output_dir = 'md_output', file_name = 'description', language = 'nl', split_only = FALSE, render_all = TRUE, chapter_number = 1, split_level = 2) {
  file_name <- paste0(file_name, '.', language, '.md')
  yml <- read_yaml('_bookdown.yml')
  name <- yml$book_filename
  bookdown_config <- '_bookdown.yml'
  media_path <- paste('description/', image_folder, sep = "")
  
  
  if (render_all) {
    chapter_number <- 1
  } else {
    book_dir = 'book_temp'
    yml$rmd_files <- c(input, "Refs.Rmd")
    write_yaml(yml, '_bookdown_temp.yml')
    bookdown_config <- '_bookdown_temp.yml'
  }
  
  # YOU CAN COMMENT THIS LINE OUT IF THE BOOK HAS ALREADY BEEN RENDERED TO ONLY PERFORM THE SPLITTING
  if (!split_only){
    bookdown::render_book(input, output_format = "bookdown::markdown_document2", clean_envir=FALSE, output_dir = book_dir, config_file = bookdown_config)
  }
  
  lines <- readLines(paste(book_dir ,'/', name, '.md', sep = ""))
  
  config <- read_json('config_template.json')
  
  base_wd <- getwd()
  
  if (!file.exists(output_dir)){
    dir.create(output_dir)
  }
  setwd(output_dir)
  
  line_type <- 'text'
  current_level <- 0
  current_index <- 1
  content_found <- FALSE 
  noNum <- FALSE
  continuation <- 0
  
  # Chapter numbers will be kept in a push/pop stack
  chapter_numbers <- numeric(0)
  chapter_name <- ""
  
  for(i in 1:length(lines)) {
    line <- lines[i]
    print(i)
    if (line_type == 'text') {
      match <- str_match(line, title_pattern)
      
      if (!is.na(match[1])) {
        # Title level is the number of #'s at the start of the line.
        # The string of #'s is captured in match[2]
        title_level <- nchar(match[2])
        if (title_level <= split_level) {
          previous_chapter <- chapter_name
          chapter_name <- match[3]
          # If content was found in previous chapter -> write it to a file
          if (content_found) {
            write_section(previous_chapter, continuation, i, lines, current_level, split_level, chapter_numbers, file_name, current_index, config, conintue_str, noNum)
            # If non-numbered chapter, reduce chapter number by 1 to skip numbering
            if (noNum) {
              num <- pop(chapter_numbers)
              push(chapter_numbers, num-1)
              noNum <- FALSE
            }
            current_index <- i
            content_found <- FALSE
            continuation <- 0
          }
          # If title is of a lower level -> make dir and step into it.
          # This will always be subsection number 1
          level_diff <- title_level - current_level
          if (level_diff == 1){
            dirname <- str_replace_all(chapter_name, "[[:punct:]]", "")
            if (!file.exists(dirname)){
              dir.create(dirname)
            }
            setwd(dirname)
            if (file.exists(media_path)){
              unlink(media_path, recursive = TRUE)
            }
            if (title_level == 1) {
              push(chapter_numbers, chapter_number)
            } else {
              push(chapter_numbers, 1)
            }
            
          } else if (level_diff < 1) {
            steps <- 1 - level_diff
            # Go back up in file structure and pop chapter_numbers to check where we were
            for (j in 1:steps){
              setwd('..')
              chapter <- pop(chapter_numbers)
            }
            chapter <- chapter + 1
            dirname <- str_replace_all(chapter_name, "[[:punct:]]", "")
            if (!file.exists(dirname)){
              dir.create(dirname)
            }
            setwd(dirname)
            if (file.exists(media_path)){
              unlink(media_path, recursive = TRUE)
            }
            push(chapter_numbers, chapter)
          } else {
            print(paste('Title structure is incorrect at line: ', toString(i)))
          }
          current_level <- title_level
        } else{
          content_found <- TRUE
        }
      }
      # check if there is any non-whitespace
      match <- str_match(line, "\\S")
      if (!is.na(match[1])) {
        content_found <- TRUE
        # check if a code block starts
        code_block_match <- str_match(line, "^[[:space:]]*```")
        image_match_html <- str_match(line, image_pattern_html)
        image_match_md <- str_match(line, image_pattern_md)
        image_match_url <- str_match(line, image_pattern_url)
        table_match <- str_match(line, table_pattern)
        mdref_match <- str_match(line, mdref_pattern)
        math_match <- str_match(line, math_pattern)
        noNum_match <- str_match(line, noNum_pattern)
        break_match <- str_match(line, break_pattern)
        href_match <- str_match(line, href_pattern)
        
        if (!is.na(code_block_match[1])) {
          # Set line type to code so lines inside a codeblock are ignored when looking for headers
          line_type <- 'code'
        } else if(!is.na(image_match_html[1])) {
          # If HTML image tag found, copy file and replace path in lines[i]
          make_image_dir(media_path)
          file_path <- paste(base_wd, "/_bookdown_files/" , image_match_html[2], sep = "")
          file.copy(from = file_path, to = media_path, overwrite = TRUE)
          lines[i] <- paste("<img src=\"",image_folder,"/",basename(image_match_html[2]),"\" width=\"70%\" style=\"display: block; margin: auto;\" />", sep = "")
        }else if(!is.na(image_match_md[1])) {
          # If MD image tag found, copy file and replace path in lines[i]
          make_image_dir(media_path)
          file_path <- paste(base_wd, "/_bookdown_files/" , image_match_md[2], sep = "")
          file.copy(from = file_path, to = media_path)
          lines[i] <- paste("<img src=\"",image_folder,"/",basename(image_match_md[2]),"\" width=\"70%\" style=\"display: block; margin: auto;\" />", sep = "")
        } else if(!is.na(image_match_url[1])) {
          lines[i] <- paste("<img src=\"",image_match_url[2],"\" width=\"70%\" style=\"display: block; margin: auto;\" />", sep = "")
        } else if(!is.na(table_match[1])) {
          lines[i] <- sub("<table", "<table class=\"table\"", line)
        } else if(!is.na(mdref_match[1])) {
          lines[i] <- gsub(mdref_pattern, "", line)
        } else if(!is.na(noNum_match[1])) {
          noNum <- TRUE
        } else if(!is.na(break_match[1])) {
          write_section(chapter_name, continuation, i, lines, current_level, split_level, chapter_numbers, file_name, current_index, config, conintue_str, noNum)
          continuation <- continuation + 1
          current_index <- i
          setwd('..')
          dirname <- paste(str_replace_all(chapter_name, "[[:punct:]]", ""), continue_str, continuation)
          if (!file.exists(dirname)){
            dir.create(dirname)
          }
          setwd(dirname)
        } 
        if (!is.na(href_match[1])) {
          lines[i] <- gsub("<a href=[^>]+>", "**", lines[i])
          lines[i] <- gsub("</a>", "**", lines[i])
        } 
        if(!is.na(math_match[1])) {
          lines[i] <- gsub(math_pattern, "$$", lines[i])
        } 
      }
    } else {
      # check if code block ends
      code_block_match <- str_match(line, "^[[:space:]]*```")
      if (!is.na(code_block_match[1])) {
        line_type <- 'text'
      }
    }
  }
  write_section(chapter_name, continuation, i, lines, current_level, split_level, chapter_numbers, file_name, current_index, config, conintue_str, noNum)
  setwd(base_wd)
  if (file.exists("_bookdown_temp.yml")){
    file.remove("_bookdown_temp.yml")
  }
  if (file.exists("book_temp")){
    unlink("book_temp", recursive=TRUE)
  }
}




# push
push <- function(x, values) {
  assign(as.character(substitute(x)), c(x, values), parent.frame())
}

# pop
pop <- function(x) {
  value <- x[length(x)]
  assign(as.character(substitute(x)), x[-length(x)], parent.frame())
  value
}

write_section <- function(chapter_name, continuation = 0, i, lines, current_level, split_level, chapter_numbers, file_name, current_index, config, conintue_str, noNum) {
  if (current_level < split_level) {
    # If we have content that is not at the deepest level of subsections
    # we make a '00' folder. This is so that the config files in Dodona dont conflict
    if (!file.exists('00')){
      dir.create('00')
    }
    setwd('00')
    push(chapter_numbers, 0)
  }
  if (!file.exists('description')){
    dir.create('description')
  }
  fileConn<-file(paste("description/", file_name, sep = ""), 'w')
  writeLines(lines[current_index:i-1], fileConn)
  close(fileConn)
  # If the config file doesnt exist yet, make one based on the template
  # If it does, read it in
  if (!file.exists('config.json')){
    config_new <- config
  } else {
    config_new <- read_json('config.json')
  }
  
  clean_chapter_name <- gsub(math_pattern, "", chapter_name)
  
  if (noNum) {
    config_new$description$names$nl <- clean_chapter_name
  } else if (continuation > 0) {
    config_new$description$names$nl <- paste(paste(chapter_numbers, collapse = "."), " ", clean_chapter_name, " (", continue_str, " ", continuation, ")", sep = "")
  } else {
    config_new$description$names$nl <- paste(paste(chapter_numbers, collapse = "."), clean_chapter_name)
  }
  
  write_json(config_new, 'config.json', pretty = TRUE, auto_unbox = TRUE)
  if (current_level < split_level) {
    # If we made a '00' folder, we now have to move back up
    setwd('..')
    pop(chapter_numbers)
  }
  
}

make_image_dir <- function(media_path) {
  if (!file.exists(media_path)){
    if (!file.exists('description')){
      dir.create('description')
    }
    dir.create(media_path)
  }
}