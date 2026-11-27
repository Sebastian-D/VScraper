# Build a per-car history from the weekly scrapes in data/volvo_price_tracker.csv.
#
# Each car appears in every weekly scrape until it is sold. This script links
# those rows into one track per car:
#   - Rows with a listing_id (scraped from 2026-11-29 on) are linked by that ID.
#   - Older rows have no ID and are linked by a fingerprint:
#       pass 1 (exact): model, model_year, engine_hk, color, description and mil identical
#       pass 2 (fuzzy): model, model_year, engine_hk, color identical and either
#         - same description, mileage up by at most MIL_PER_WEEK per week
#           (MIL_PER_WEEK_GAP if a complete scrape was missed) ("creep"), or
#         - description edited, mileage unchanged, and no conflicting trim level
#           (Core/Plus/Ultra/...) named ("desc_change").
#         A fuzzy link is made only when the row and the track are each other's
#         only candidate; otherwise the row is flagged ambiguous and starts a new car.
#   - The first rows with an ID are linked to the existing fingerprint tracks the
#     same way, so cars listed before the ID was captured keep their history.
# Price is never used for matching.
#
# Outputs:
#   data/cars_history.csv     one row per car
#   data/car_observations.csv one row per car per scrape (raw rows + car_id)
#   data/scrape_dates.csv     one row per scrape date, with incomplete scrapes flagged
#   data/match_report.md      counts for checking the matching logic

suppressPackageStartupMessages(library(tidyverse))

RAW_PATH        <- "data/volvo_price_tracker.csv"
MAX_MISSED      <- 2     # complete scrapes a car may be absent and still be linked / count as active
MIL_PER_WEEK    <- 150   # max mileage increase per week for a "creep" link (1 mil = 10 km)...
MIL_PER_WEEK_GAP <- 10   # ...and when the car was missing from a complete scrape in between
# Thresholds were chosen by checking linked prices (not used for matching): links
# between consecutive scrapes were clean up to 150 mil/week, while links bridging
# a missed scrape above 10 mil/week, and description edits with any mileage change,
# often joined two different cars (trim level and price jumped).
INCOMPLETE_RATIO <- 0.5  # a model year's scrape is incomplete below this share of its neighbours' median
INCOMPLETE_MIN_REF <- 5  # ...only judged when the neighbours' median is at least this many cars

# Volvo renamed its electric models (XC40 Recharge -> EX40, C40 Recharge -> EC40);
# all cars here are electric, so "XC40" and "C40" are the same cars under older names.
# Matching still uses the listed model; the family is for grouping in the dashboard.
model_family <- function(model) {
  case_when(model %in% c("XC40", "XC40 Recharge", "EX40") ~ "EX40 / XC40",
            model %in% c("C40", "C40 Recharge", "EC40") ~ "EC40 / C40",
            TRUE ~ model)
}

# Trim level named in a free-text description (NA if none)
trim_of <- function(desc) {
  str_to_lower(str_extract(desc, regex("\\b(core|plus|ultra|ultimate|pro|start)\\b", ignore_case = TRUE)))
}

key_invariant <- c("model", "model_year", "engine_hk", "color")
key_exact     <- c(key_invariant, "description", "mil")

# ---- Read and clean ---------------------------------------------------------
raw <- read_csv(RAW_PATH, show_col_types = FALSE)
if (!"listing_id" %in% names(raw)) raw$listing_id <- NA_character_
raw <- raw %>% mutate(listing_id = as.character(listing_id))
n_raw <- nrow(raw)

obs <- distinct(raw)
n_exact_dups <- n_raw - nrow(obs)
exact_dups_by_date <- raw %>% count(scrape_date, name = "rows") %>%
  left_join(count(obs, scrape_date, name = "kept"), by = "scrape_date") %>%
  mutate(removed = rows - kept) %>% filter(removed > 0)

# A listing ID seen twice on one date (e.g. different price mid-scrape): keep one
n_before <- nrow(obs)
obs <- bind_rows(
  filter(obs, is.na(listing_id)),
  filter(obs, !is.na(listing_id)) %>% distinct(scrape_date, listing_id, .keep_all = TRUE)
)
n_id_dups <- n_before - nrow(obs)

dates <- sort(unique(obs$scrape_date))
obs <- obs %>%
  mutate(date_idx = match(scrape_date, dates)) %>%
  arrange(date_idx, model_year, model, price) %>%
  mutate(obs_id = row_number(), car_id = NA_character_,
         match_method = NA_character_, ambiguous = FALSE)

# ---- Scrape completeness per model year ---------------------------------------
# Compare each (date, model year) count with the median of the two scrapes before
# and after it. An incomplete scrape doesn't count as "the car disappeared".
year_counts <- obs %>%
  count(date_idx, model_year) %>%
  complete(date_idx = seq_along(dates), model_year, fill = list(n = 0)) %>%
  group_by(model_year) %>% arrange(date_idx, .by_group = TRUE) %>%
  mutate(ref = map_dbl(date_idx, function(i) {
    nb <- n[date_idx %in% c(i - 2, i - 1, i + 1, i + 2)]
    if (length(nb) == 0) NA_real_ else median(nb)
  }),
  complete = !(ref >= INCOMPLETE_MIN_REF & n < INCOMPLETE_RATIO * ref)) %>%
  ungroup() %>%
  mutate(complete = replace_na(complete, TRUE), scrape_date = dates[date_idx])

complete_idx <- year_counts %>% filter(complete) %>%
  group_by(model_year) %>% summarise(idx = list(sort(date_idx))) %>% deframe()

# Number of complete scrapes of a model year strictly between two date indexes
missed_between <- function(model_year, from_idx, to_idx) {
  map2_int(as.character(model_year), seq_along(from_idx), function(my, k) {
    ci <- complete_idx[[my]]
    if (is.null(ci)) return(0L)
    sum(ci > from_idx[k] & ci < to_idx[k])
  })
}

# ---- Link rows into tracks, one scrape at a time -----------------------------
tracks <- tibble(car_id = character(), listing_id = character(), model = character(),
                 model_year = numeric(), engine_hk = numeric(), color = character(),
                 description = character(), mil = numeric(), last_idx = integer())
next_car <- 1L
ambiguous_cases <- list()

assign_rows <- function(obs, ids, car_ids, method) {
  m <- match(obs$obs_id, ids)
  hit <- !is.na(m)
  obs$car_id[hit] <- car_ids[m[hit]]
  obs$match_method[hit] <- method
  obs
}

for (i in seq_along(dates)) {
  rows <- obs %>% filter(date_idx == i) %>% select(-car_id, -match_method, -ambiguous)
  open <- tracks %>%
    mutate(missed = missed_between(model_year, last_idx, rep(i, n()))) %>%
    filter(missed <= MAX_MISSED)
  pairs <- list()

  # A: listing ID (any earlier track with that ID, however long ago)
  a <- rows %>% filter(!is.na(listing_id)) %>%
    inner_join(select(tracks, car_id, listing_id), by = "listing_id")
  pairs$id <- select(a, obs_id, car_id)
  rows <- anti_join(rows, a, by = "obs_id")
  open_fp <- open %>% filter(is.na(listing_id))  # tracks still identified by fingerprint only

  # B: exact fingerprint, paired one-to-one within each identical key
  b <- inner_join(
    rows %>% group_by(across(all_of(key_exact))) %>% mutate(k = row_number()) %>% ungroup(),
    open_fp %>% arrange(desc(last_idx)) %>% group_by(across(all_of(key_exact))) %>%
      mutate(k = row_number()) %>% ungroup() %>% select(all_of(key_exact), k, car_id),
    by = c(key_exact, "k"))
  pairs$exact <- select(b, obs_id, car_id)
  rows <- anti_join(rows, b, by = "obs_id")
  open_fp <- filter(open_fp, !car_id %in% b$car_id)

  # C: fuzzy fingerprint, mutual-unique candidates only
  cand <- inner_join(rows, open_fp, by = key_invariant, suffix = c("", ".t"),
                     relationship = "many-to-many") %>%
    mutate(weeks = as.numeric(dates[i] - dates[last_idx]) / 7,
           dmil = mil - mil.t,
           same_desc = description == description.t,
           max_creep = if_else(missed == 0, MIL_PER_WEEK, MIL_PER_WEEK_GAP) * weeks,
           method = case_when(
             same_desc & dmil > 0 & dmil <= max_creep ~ "creep",
             # an edited description must not name a different trim level
             !same_desc & dmil == 0 &
               !coalesce(trim_of(description) != trim_of(description.t), FALSE) ~ "desc_change")) %>%
    filter(!is.na(method)) %>%
    add_count(obs_id, name = "n_row") %>% add_count(car_id, name = "n_track")
  c_ok <- filter(cand, n_row == 1, n_track == 1)
  pairs$fuzzy <- select(c_ok, obs_id, car_id, method)
  c_amb <- filter(cand, n_row > 1 | n_track > 1)
  if (nrow(c_amb) > 0) {
    ambiguous_cases[[length(ambiguous_cases) + 1]] <- c_amb %>%
      transmute(scrape_date = dates[i], obs_id, candidate_car = car_id, model, model_year,
                color, description, description.t, mil, mil.t, dmil, method)
    obs$ambiguous[obs$obs_id %in% c_amb$obs_id] <- TRUE
  }

  # Apply links and update the matched tracks
  obs <- assign_rows(obs, pairs$id$obs_id, pairs$id$car_id, "id")
  obs <- assign_rows(obs, pairs$exact$obs_id, pairs$exact$car_id, "exact")
  for (m in c("creep", "desc_change")) {
    p <- filter(pairs$fuzzy, method == m)
    obs <- assign_rows(obs, p$obs_id, p$car_id, m)
  }

  # D: everything else is a new car
  new_rows <- obs %>% filter(date_idx == i, is.na(car_id))
  if (nrow(new_rows) > 0) {
    new_ids <- sprintf("car%05d", next_car:(next_car + nrow(new_rows) - 1))
    next_car <- next_car + nrow(new_rows)
    obs <- assign_rows(obs, new_rows$obs_id, new_ids, "new")
  }

  # Refresh track state from this scrape's rows
  seen <- obs %>% filter(date_idx == i) %>%
    transmute(car_id, listing_id, model, model_year, engine_hk, color, description, mil, last_idx = i)
  kept_ids <- tracks %>% semi_join(seen, by = "car_id") %>% select(car_id, old_id = listing_id)
  seen <- seen %>% left_join(kept_ids, by = "car_id") %>%
    mutate(listing_id = coalesce(listing_id, old_id)) %>% select(-old_id)
  tracks <- bind_rows(anti_join(tracks, seen, by = "car_id"), seen)
}

# ---- Per-car history --------------------------------------------------------
latest_idx <- length(dates)

cars <- obs %>%
  arrange(car_id, date_idx) %>%
  group_by(car_id) %>%
  summarise(
    listing_id = last(na.omit(listing_id)) %||% NA_character_,
    model = first(model), model_year = first(model_year), engine_hk = first(engine_hk),
    color = first(color), description = last(description),
    first_seen = min(scrape_date), last_seen = max(scrape_date),
    last_idx = max(date_idx), n_scrapes = n(),
    first_price = first(price), last_price = last(price),
    min_price = min(price), max_price = max(price),
    n_price_drops = sum(diff(price) < 0),
    total_price_drop = sum(pmax(-diff(price), 0)),
    n_price_increases = sum(diff(price) > 0),
    first_mil = first(mil), last_mil = last(mil),
    fuzzy_links = sum(match_method %in% c("creep", "desc_change")),
    ambiguous = any(ambiguous),
    .groups = "drop") %>%
  mutate(
    listing_id = if_else(listing_id == "", NA_character_, listing_id),
    missed_since = missed_between(model_year, last_idx, rep(latest_idx + 1L, n())),
    status = if_else(missed_since >= MAX_MISSED, "presumed_sold", "active"),
    days_on_market = as.integer(last_seen - first_seen),
    # Already listed at the first scrape: the true listing date is unknown
    listed_before_tracking = first_seen == dates[1],
    price_change_pct = round(100 * (last_price - first_price) / first_price, 1)) %>%
  select(-last_idx, -missed_since) %>%
  mutate(model_family = model_family(model), .after = model) %>%
  arrange(first_seen, car_id)

write_csv(cars, "data/cars_history.csv", na = "")
obs %>%
  mutate(model_family = model_family(model)) %>%
  select(car_id, listing_id, scrape_date, model, model_family, model_year, engine_hk, color,
         description, mil, price, match_method, ambiguous) %>%
  arrange(car_id, scrape_date) %>%
  write_csv("data/car_observations.csv", na = "")

# One row per scrape date, for marking incomplete scrapes in the dashboard
year_counts %>%
  group_by(scrape_date) %>%
  summarise(cars = sum(n),
            incomplete_model_years = paste(model_year[!complete], collapse = ", "),
            complete = all(complete)) %>%
  write_csv("data/scrape_dates.csv", na = "")

# ---- Match report -----------------------------------------------------------
amb <- bind_rows(ambiguous_cases)
methods <- count(obs, match_method) %>% deframe()
m <- function(x) if (is.na(methods[x])) 0L else methods[[x]]
incomplete <- year_counts %>% filter(!complete) %>%
  transmute(scrape_date, model_year, n, ref = round(ref))
# Gaps between consecutive scrapes longer than 8 days
gaps <- tibble(from = head(dates, -1), to = tail(dates, -1)) %>%
  mutate(days = as.integer(to - from)) %>% filter(days > 8)

md_table <- function(df) {
  if (nrow(df) == 0) return("_none_\n")
  df <- mutate(df, across(everything(), as.character))
  paste0("| ", paste(names(df), collapse = " | "), " |\n",
         "|", paste(rep("---", ncol(df)), collapse = "|"), "|\n",
         paste0("| ", apply(df, 1, paste, collapse = " | "), " |", collapse = "\n"), "\n")
}

report <- c(
  "# Match report", "",
  sprintf("Generated %s from `%s` (%d scrapes, %s to %s).", Sys.Date(), RAW_PATH,
          length(dates), min(dates), max(dates)), "",
  "## Input cleaning",
  sprintf("- Raw rows: %d", n_raw),
  sprintf("- Exact duplicate rows removed: %d", n_exact_dups),
  sprintf("- Same listing_id twice on one date, removed: %d", n_id_dups),
  sprintf("- Observations kept: %d", nrow(obs)), "",
  "Exact duplicates by date:", "", md_table(exact_dups_by_date), "",
  "Scrapes judged incomplete (absence there doesn't count towards \"sold\"):", "",
  md_table(incomplete), "",
  "Gaps of more than 8 days between scrapes:", "", md_table(gaps), "",
  "## Linking",
  sprintf("- Linked by listing_id: %d", m("id")),
  sprintf("- Linked by exact fingerprint: %d", m("exact")),
  sprintf("- Linked by mileage creep (same description, up to %d mil/week, %d if a scrape was missed): %d",
          MIL_PER_WEEK, MIL_PER_WEEK_GAP, m("creep")),
  sprintf("- Linked despite edited description (same mileage): %d", m("desc_change")),
  sprintf("- Started a new car: %d", m("new")),
  sprintf("- Of which ambiguous (several candidates, left unlinked): %d rows",
          n_distinct(amb$obs_id %||% integer())), "",
  "## Cars",
  sprintf("- Unique cars: %d", nrow(cars)),
  sprintf("- Active: %d, presumed sold: %d", sum(cars$status == "active"), sum(cars$status == "presumed_sold")),
  sprintf("- Cars with at least one fuzzy link: %d", sum(cars$fuzzy_links > 0)),
  sprintf("- Cars touched by an ambiguous match: %d", sum(cars$ambiguous)),
  sprintf("- Seen in only one scrape: %d", sum(cars$n_scrapes == 1)),
  sprintf("- Already listed at first scrape (true listing date unknown): %d", sum(cars$listed_before_tracking)),
  sprintf("- Cars with at least one price drop: %d", sum(cars$n_price_drops > 0)), "",
  "## Ambiguous cases (first 25)", "",
  md_table(head(amb %>% select(-obs_id), 25)), "",
  "## Fuzzy links (first 25)", "",
  md_table(obs %>% filter(match_method %in% c("creep", "desc_change")) %>%
             group_by(car_id) %>% slice_head(n = 1) %>% ungroup() %>%
             left_join(obs %>% select(car_id, date_idx, prev_desc = description, prev_mil = mil),
                       by = "car_id", relationship = "many-to-many") %>%
             filter(date_idx.y < date_idx.x) %>% group_by(obs_id) %>% slice_max(date_idx.y, n = 1) %>%
             ungroup() %>%
             transmute(scrape_date, car_id, model, model_year, match_method,
                       prev_desc, description, prev_mil, mil) %>% head(25))
)
writeLines(report, "data/match_report.md")
cat(report[1:which(report == "## Ambiguous cases (first 25)") - 1], sep = "\n")
