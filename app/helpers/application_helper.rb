module ApplicationHelper
  # get a UTC timestamp in local time, formatted all purty-like
  def local_timestamp(utc_time)
    Time.zone.parse(utc_time).strftime("%F %R")
  end
end
