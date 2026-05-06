# Volvo selekt webscraper

library(tidyverse)
library(chromote)
library(rvest)

# Initialize the browser
b <- ChromoteSession$new()

scrape_volvo_page <- function(model_year, page_num) {
  url <- paste0("https://selekt.volvocars.se/sv-se/store/all/vehicles?franchiseApproved=true&modelYearAbove=",model_year,"&modelYearBelow=",model_year,"&fuel=Electric&pageNumber=", page_num)

  b$Page$navigate(url)
  Sys.sleep(3) # Give the JS time to load the cars

  # Get the rendered HTML
  html <- b$Runtime$evaluate("document.documentElement.outerHTML")$result$value %>%
    read_html()

  # Identify the car cards (you will need to check the exact CSS class, e.g., ".vehicle-card")
  car_cards <- html %>% html_elements(".card-main-container")

  # If no cards are found, we assume we've reached the end of the listings
  if (length(car_cards) == 0) return(NULL)

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

  return(page_data)
}

# Loop through all model years from 2020 to current year
current_year <- as.numeric(format(Sys.Date(), "%Y"))
model_years <- 2020:current_year

# Loop through years and pages
all_cars <- list()
all_cars_page <- list() # To store data for each page before combining

# for loop to iterate through model years and pages
for (model_year in model_years) {
  message(paste("Starting to scrape model year", model_year))
  page <- 1
  keep_going <- TRUE

  while(keep_going) {
    message(paste("Scraping page", page))
    current_page_data <- scrape_volvo_page(model_year, page)

    if (is.null(current_page_data)) {
      keep_going <- FALSE
    } else {
      all_cars_page[[page]] <- current_page_data
      page <- page + 1
    }
  }
  all_cars[[model_year]] <- bind_rows(all_cars_page)
  all_cars_page <- list() # Reset for the next model year
}

final_df <- bind_rows(all_cars)

# Save to a CSV (appending if file exists)
write_excel_csv(final_df, "data/volvo_price_tracker.csv", append = file.exists("data/volvo_price_tracker.csv"))