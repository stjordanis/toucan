require "rubygems"
require "bundler/setup"
require "redis"
require "pp"

$redis = Redis.new

def add_event(timestamp, category, key, value, properties = {}, properties_with_counts = {})
  pairs = {}
  begin
    pairs[key.join(".")] = value
  end while key.pop and !key.empty?

  pairs.each do |key, val|
    $redis.incrby("lifetime:#{key}", val)
    hour = round_time(timestamp, 3600)
    $redis.incrby("hour.#{hour}:#{key}", val)
    minute = round_time(timestamp, 60)
    $redis.incrby("minute.#{minute}:#{key}", val)
    # use date for day YYYY-MM-DD instead of timestamp
    # need to account for time zone
    day = Time.at(timestamp).to_date.strftime("%Y-%m-%d")
    $redis.incrby("day.#{day}:#{key}", val)
  end
end

def round_time(timestamp, seconds = 60)
  (timestamp.to_f / seconds).floor * seconds
end

def minute_counts(key, points = 10, seconds = 60, prefix = "minute")
  last = round_time(Time.now, seconds)
  first = last - (points - 1) * seconds
  steps = *(first..last).step(seconds)

  count_helper(key, prefix, steps)
end

def hour_counts(key, points = 10)
  minute_counts(key, points, 3600, "hour")
end

def day_counts(key, points = 10)
  last = Date.today
  first = last - (points - 1)
  steps = *first.step(last)

  count_helper(key, "day", steps)
end

def lifetime_counts(key)
  value = $redis.get("lifetime:#{key}")

  puts "lifetime - #{key} - #{value}"
end

def count_helper(key, prefix, steps)
  keys = steps.map{|step| "#{prefix}.#{step}:#{key}"}

  # get keys and replace nils with zero
  values = $redis.mget(*keys).map{|val| (val || 0).to_i }

  values = Hash[steps.map{|step| step = step.strftime("%Y-%m-%d") if step.is_a?(Date); [step, values.shift]}]

  puts "#{prefix} - #{key}"
  pp values
  puts
end
