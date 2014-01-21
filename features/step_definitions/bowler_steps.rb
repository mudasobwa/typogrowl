# encoding: utf-8

Given(/^we use "(.*?)" bowler$/) do |f|
#  @f = "config/bowlers/#{f}.yaml"
  f = "#{f}#{@suffix}" unless @suffix.nil? 
  @bowler = Qipowl::Ruler.new_bowler f
end

When(/^the input string is "(.*?)"$/) do |input|
  @input = input
end

When(/^the input string is$/) do |input|
  @input = input
end

When(/^the execute method is called on bowler$/) do
  @result = @bowler.execute @input
end

When(/^rule "(.*?)" is added to mapping as "(.*?)" in "(.*?)" section with "(.*?)" enclosure$/) do |key, val, section, encl|
  @bowler.add_entity section, key, val, encl
end

When(/^rule "(.*?)" is removed from mapping$/) do |key|
  @bowler.remove_entity key
end

Then(/^bowler has all the method aliases$/) do
  puts @bowler.class.instance_methods(false)
  puts '='*60
  @bowler.class.constants(false).each { |c|
    puts "Constant: #{c}"
    puts @bowler.class.const_get(c)
    puts '-'*60
  }
end

Then(/^the output is "(.*?)"$/) do |result|
  expect(@result).to eq(result)
end

