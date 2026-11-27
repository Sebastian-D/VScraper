# Volvo selekt webscraper

library(tidyverse)
library(chromote)
library(rvest)

csv_path <- "data/volvo_price_tracker.csv"

# Initialize the browser
b <- ChromoteSession$new()

# Wait until the JS-rendered car cards (or an empty result page) have appeared,
# instead of a fixed sleep. A fixed sleep sometimes returned a half-loaded page,
# which ended paging early and produced partial scrapes.
get_rendered_html <- function(timeout = 20) {
  start <- Sys.time()
  repeat {
    Sys.sleep(1)
    n_cards <- b$Runtime$evaluate(
      "document.querySelectorAll('.card-main-container').length"
    )$result$value
    count_text <- b$Runtime$evaluate(
      "(document.querySelector('[data-e2e=\"@searchPage/vehicleCount\"]') || {}).textContent || ''"
    )$result$value
    elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
    # Cards found: give the rest of the page a moment to finish rendering
    if (n_cards > 0) { Sys.sleep(1); break }
    # Page rendered and the site reports no cars for this search
    if (str_trim(count_text) == "0") break
    if (elapsed > timeout) break
  }
  b$Runtime$evaluate("document.documentElement.outerHTML")$result$value %>%
    read_html()
}

scrape_volvo_page <- function(model_year, page_num) {
  url <- paste0("https://selekt.volvocars.se/sv-se/store/all/vehicles?franchiseApproved=true&modelYearAbove=",model_year,"&modelYearBelow=",model_year,"&fuel=Electric&pageNumber=", page_num)

  # Blank the page first so cards left over from the previous page can't be read
  b$Page$navigate("about:blank")
  b$Page$navigate(url)
  html <- get_rendered_html()

  # Total number of cars the site reports for this search (used to verify completeness)
  total <- html %>% html_element('[data-e2e="@searchPage/vehicleCount"]') %>% html_text2() %>%
    str_remove_all("\\D") %>% as.numeric()

  car_cards <- html %>% html_elements(".card-main-container")

  # If no cards are found, we assume we've reached the end of the listings
  if (length(car_cards) == 0) return(list(data = NULL, total = total))

  # Extraction logic for the map_df function
  page_data <- map_df(car_cards, function(card) {

    # Get all marketing feature blocks (Fuel, Power, Mileage, etc.)
    features <- card %>% html_elements('[data-e2e="@vehicleCard/marketingFeature"]')

    # Helper function to find a value based on its label
    get_feature <- function(nodes, label_text) {
      node <- nodes[detect_index(nodes, ~str_detect(html_text(.x), label_text))]
      node %>% html_element(".font-weight-bold") %>% html_text2()
    }

    tibble(
      # Stable per-car stock ID (Codeweavers stock UUID). It is the key in the
      # vehicle detail URL and sits in the card's compare-checkbox id ("None-<uuid>").
      listing_id  = card %>% html_element("input.cw-checkbox-input") %>% html_attr("id") %>%
                      str_remove("^None-"),
      model       = card %>% html_element("h3") %>% html_text2(),
      price       = card %>% html_element('[data-e2e="@vehicleResult/cashPrice"] span') %>% html_text2(),
      description = card %>% html_element(".text-ellipsis small") %>% html_text2(),

      # We find these by searching the labels inside the marketing features
      engine_hk = get_feature(features, "Motoreffekt"),
      mil = get_feature(features, "Miltal"),
      color = get_feature(features, "Färg"),
      fuel = get_feature(features, "Bränsle"),
      automatic = get_feature(features, "Växellåda"),
      model_year = model_year,
      scrape_date = Sys.Date()
    )
  })

  # Clean up the data a bit
  # Remove "Hk" from engine_hk and convert to numeric
  # Remove "mil" from mil and convert to numeric
  # Remove "kr" and spaces from price and convert to numeric
  # if automatic is "Automatisk" set to TRUE, else FALSE
  page_data <- page_data %>%
    mutate(
      engine_hk = as.numeric(str_remove(engine_hk, " Hk")),
      mil = as.numeric(str_remove_all(mil, "[ mil]")),
      price = as.numeric(str_remove_all(price, "[ kr]")),
      automatic = if_else(automatic == "Automatisk", TRUE, FALSE)
    )

  return(list(data = page_data, total = total))
}

# Scrape every page of one model year. An empty page is re-fetched once before
# it is taken as the end of the listings (a slow page load looks like an empty page).
scrape_model_year <- function(model_year) {
  pages <- list()
  total <- NA
  page <- 1
  n_cars <- function() n_distinct(bind_rows(pages)$listing_id)
  repeat {
    message(paste("Scraping page", page))
    res <- scrape_volvo_page(model_year, page)
    if (is.na(total)) total <- res$total
    # The site reports no cars for this year: nothing more to fetch
    if (is.null(res$data) && isTRUE(total == 0)) break
    if (is.null(res$data)) res <- scrape_volvo_page(model_year, page)
    if (is.na(total)) total <- res$total
    if (is.null(res$data)) break
    pages[[page]] <- res$data
    # Stop once every car the site reports has been collected, instead of
    # requesting (and waiting out) an empty page after the last one
    if (!is.na(total) && n_cars() >= total) break
    page <- page + 1
  }
  cars <- bind_rows(pages)
  if (nrow(cars) > 0) cars <- distinct(cars, listing_id, .keep_all = TRUE)
  list(data = cars, total = total)
}

# Loop through all model years from 2020 to current year
current_year <- as.numeric(format(Sys.Date(), "%Y"))
model_years <- 2020:current_year

all_cars <- list()
problems <- character()

for (model_year in model_years) {
  message(paste("Starting to scrape model year", model_year))
  best <- NULL
  # Retry the model year if the results page didn't render (no vehicle count shown;
  # a year with no cars still shows "0") or fewer cars were collected than reported
  for (attempt in 1:3) {
    res <- scrape_model_year(model_year)
    if (is.null(best) || nrow(res$data) > nrow(best$data) || is.na(best$total)) best <- res
    if (!is.na(res$total) && nrow(res$data) >= res$total) break
    message(sprintf("Model year %d attempt %d: got %d cars, site reports %s; retrying in 30 s",
                    model_year, attempt, nrow(res$data), res$total))
    Sys.sleep(30)
  }
  message(sprintf("Model year %d: %d cars collected, site reports %s", model_year, nrow(best$data), best$total))
  if (is.na(best$total) || nrow(best$data) < best$total) {
    problems <- c(problems, sprintf("Model year %d incomplete: %d cars collected, site reports %s",
                                    model_year, nrow(best$data), best$total))
    # Keep what the browser saw, for diagnosis (uploaded by the workflow on failure)
    dir.create("debug", showWarnings = FALSE)
    try(b$screenshot(sprintf("debug/model_year_%d.png", model_year)), silent = TRUE)
    try(writeLines(b$Runtime$evaluate("document.documentElement.outerHTML")$result$value,
                   sprintf("debug/model_year_%d.html", model_year)), silent = TRUE)
  }
  all_cars[[as.character(model_year)]] <- best$data
}

final_df <- bind_rows(all_cars)

# Fail the run visibly: "::error::" lines show up as annotations on the GitHub run
fail_run <- function(msgs) {
  cat(paste0("::error::", msgs, "\n"), sep = "")
  quit(status = 1)
}

if (nrow(final_df) == 0) fail_run(c(problems, "Scrape returned no cars; leaving the CSV untouched."))

# A car can show up on two pages if listings shift while paging: keep one row per car.
n_before <- nrow(final_df)
final_df <- final_df %>% distinct(listing_id, .keep_all = TRUE)
message(sprintf("Scraped %d cars (%d duplicate rows from paging removed); %d rows missing listing_id",
                nrow(final_df), n_before - nrow(final_df), sum(is.na(final_df$listing_id))))

# Save: rewrite the whole CSV, replacing any rows already saved for today's date,
# so running the scraper twice on one day can't duplicate that day's data.
# (Rows from before listing_id was captured have NA in that column.)
if (file.exists(csv_path)) {
  existing <- read_csv(csv_path, col_types = cols(
    listing_id = col_character(), model = col_character(), price = col_double(),
    description = col_character(), engine_hk = col_double(), mil = col_double(),
    color = col_character(), fuel = col_character(), automatic = col_logical(),
    model_year = col_double(), scrape_date = col_date()
  ))
  existing <- existing %>% filter(scrape_date != Sys.Date())
  final_df <- bind_rows(existing, final_df)
}

final_df <- final_df %>% relocate(listing_id)
write_excel_csv(final_df, csv_path)

# Partial data is saved (the processing script flags incomplete scrapes), but the run fails
if (length(problems) > 0) fail_run(problems)
