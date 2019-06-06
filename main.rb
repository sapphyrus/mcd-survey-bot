require "bundler/inline"

gemfile($DEBUG) do
	source "https://rubygems.org"

	gem "telegram-bot-ruby", :require => "telegram/bot"
	gem "selenium-webdriver", "~> 3.6.0"
	gem "phantomjs"
	gem "chunky_png"

	require "securerandom"
	require "json"
	require "uri"
	require "net/http"
	require "net/https"

	# development dependencies
	gem "pry" if $DEBUG
end

class Selenium::WebDriver::Element
	def children
		self.find_elements(:xpath, "./*")
	end
end

class McDonaldsSurveySolver
	attr_accessor :log

	def initialize()
		@log = ""
		@tempfiles = []
	end

	def cleanup()
		@tempfiles.each do |tempfile|
			File.delete(tempfile) if File.file?(tempfile) rescue nil
		end
		@tempfiles = []
	end

	def fix_text(input)
		result = ""
		input.split("").each do |chr|
			result += chr if chr.ord < 250
		end
		return result.chomp.chomp(" ").reverse.chomp(" ").reverse
	end

	def puts(str)
		@log += "#{Time.now.strftime('[%H:%M:%S]')} #{str}\n"
		$stdout.puts str
	end

	def randomize_str(template)
		# template: "Ich {Möchte|Ich möchte|Ich will|ich will|will} {hierzu|dazu|dadrauf|darauf} keine {Antwort|antwort|Auskunft|auskunft} {geben|abgeben|sagen}{|.}"
		out_str = ""
		template.split("{").each do |template_part|
			random_part = template_part.split("}")
			if random_part != nil && random_part.length > 0
				out_str += random_part.shift.split("|").sample
				out_str += random_part.join("}") if random_part.length > 0
			end
		end
		return out_str.chomp(" ").reverse.chomp(" ").reverse.gsub("  ", " ")
	end

	def generate_exception_message(e = nil)
		return e == nil ? "" : "#{e.class.to_s}: #{e.message.to_s} (#{e.backtrace.inspect})"
	end

	def fetch_voucher(code, text_answer, url)
		result = {
			:success => false,
			:message => "message not set"
		}

		puts "Attempting to fetch voucher for #{code}, launching phantomjs"
		begin
			wait = Selenium::WebDriver::Wait.new(:timeout => 10)
			wait_short = Selenium::WebDriver::Wait.new(:timeout => 1)
			browser = Selenium::WebDriver.for :phantomjs
			browser.manage.window.size = Selenium::WebDriver::Dimension.new(570, 750)
			browser.navigate.to url
		rescue StandardError => e
			result[:message] = "Failed to setup web browser (internal error)!\n#{generate_exception_message(e)}"
			return result
		end

		image_path = nil
		begin
			@tempfiles << image_path = Tempfile.new(['mcdbot', '.png']).path
		rescue StandardError => e
			result[:message] = "Failed to setup temporary file (internal error)!\n#{generate_exception_message(e)}"
			return result
		end

		begin
			puts "Entering receipt code"
			code_el = wait.until do
				browser.find_element(css: "#receiptCode")
			end

			browser.action.send_keys(code_el, code + "\n").perform
			start_url = browser.current_url

			40.times do
				break if browser.current_url != start_url
				begin
					error_el = browser.find_element(css: "#errorMessage")
					unless error_el.nil?
						result[:message] = "Failed to use code: #{error_el.text}"
						result[:image] = browser.save_screenshot(image_path)
						return result
					end
				rescue Selenium::WebDriver::Error::NoSuchElementError
					sleep 0.5
				end
			end

			unless browser.current_url.start_with? "https://voice.fast-insight.com/s/"
				result[:message] = "**Failed to get redirected to survey!**\nCurrent URL: #{browser.current_url}"
				result[:image] = browser.save_screenshot(image_path)
				return result
			end
			puts "Got redirected to survey at '#{browser.current_url}', filling out."

			progress_el = wait.until do
				browser.find_element(xpath: "//*[@id=\"control-wrapper\"]/div/div[1]/div[2]")
			end
			wait.until do
				browser.find_element(xpath: '//*[@id="survey-form"]/div[2]')
			end

			question_prev = nil
			fails = 0
			loop do
				begin
					begin
						question = wait_short.until do
							browser.find_element(xpath: '//*[@id="survey-form"]/div[2]/div[3]/h3').text
						end
					rescue Selenium::WebDriver::Error::TimeOutError => e
						if progress_el.text == "100%"
							puts "[#{progress_el.text}] Done with questions."
							break
						else
							result[:message] = "**Failed to find question!**\n#{generate_exception_message(e)}"
							result[:image] = browser.save_screenshot(image_path)
							return result
						end
					end

					if question == question_prev
						if fails > 4
							puts "[#{progress_el.text}] Didn't pass question '#{question}' after 5 tries."
							result[:message] = "**Failed to answer question after 5 tries!**\nQuestion: `#{question}`"
							result[:image] = browser.save_screenshot(image_path)
							return result
						else
							puts "[#{progress_el.text}] Didn't pass question, trying again"
						end
						fails += 1
					else
						fails = 0
					end

					begin
						rate_els = browser.find_elements(xpath: "//*[@id=\"survey-form\"]/div[2]/div[5]/*")
						options_amount = rate_els.length

						case options_amount
						when 1
							if rate_els[0].tag_name == "div" && rate_els[0].attribute("class").include?("select") && rate_els[0].children.length == 1 && rate_els[0].children[0].tag_name == "select"
								#select
								select_el = Selenium::WebDriver::Support::Select.new(rate_els[0].children[0])
								options = select_el.options
								option = options.sample
								puts "[#{progress_el.text}] Answering '#{question}' with '#{fix_text(option.text)}'"

								select_el.select_by(:index, options.find_index(option))
							elsif rate_els[0].children.length == 1 && rate_els[0].children[0].tag_name == "input" && rate_els[0].children[0].attribute("type") == "text"
								#text input
								text_el = rate_els[0].children[0]
								text_el.click

								answer = randomize_str(text_answer)
								puts "[#{progress_el.text}] Answering '#{question}' with '#{answer}'"

								browser.action.send_keys(text_el, answer).perform
							elsif browser.find_elements(xpath: "//*[@id=\"survey-form\"]/div[2]/div[5]/div")[0].attribute("class").include? "ratingbar-container"
								#stars
								question_max = browser.find_elements(xpath: "//*[@id=\"survey-form\"]/div[2]/div[5]/div")[0].attribute("steps").to_i
								question_min = [1, question_max-2].max

								rating = rand(question_max-question_min+1)+question_min
								puts "[#{progress_el.text}] Answering '#{question}' with #{rating} stars"

								rate_el = wait_short.until do
									browser.find_element(xpath: "//*[@id=\"survey-form\"]/div[2]/div[5]/div/div[1]/div[#{rating}]")
								end
								rate_el.click
							elsif rate_els[0].tag_name == "div" && rate_els[0].attribute("class").include?("option")
								puts "[#{progress_el.text}] Answering '#{question}' with '#{fix_text(rate_els[0].text)}'."

								rate_els[0].click
							else
								result[:message] = "**1 Option found but no filter matched**!\nQuestion: `#{question}`\n#{generate_exception_message(e)}"
								result[:image] = browser.save_screenshot(image_path)
								return result
							end
						else
							if rate_els.count > 8
								# probably 0-10
								rate_els = rate_els[0..3]
							elsif rate_els.count == 2
								# probably yes or no question?
								rate_els.each_with_index do |el, i|
									if el.text.downcase.include?("ja") || el.text.downcase.include?("yes")
										rate_els = rate_els[i..i]
										break
									end
								end
							end

							rate_el = rate_els.sample
							puts "[#{progress_el.text}] Answering '#{question}' with '#{fix_text(rate_el.text)}'"
							rate_el.click
						end
					rescue StandardError => e
						result[:message] = "**Failed to answer question**!\nQuestion: `#{question}`\n#{generate_exception_message(e)}"
						result[:image] = browser.save_screenshot(image_path)
						return result
					end

					sleep 0.15
					confirm = wait_short.until do
						browser.find_element(css: "#next-sbj-btn")
					end
					confirm.click
					question_prev = question

					sleep 0.05
				rescue StandardError => e
				 	break
				end
			end

			url_prev = browser.current_url
			puts "Survey filled out, confirming send."
			send_el = wait.until do
				browser.find_element(xpath: "//*[@id=\"survey-form\"]/div[1]/div[3]/button")
			end
			send_el.click

			40.times do
				break if browser.current_url != url_prev
				sleep 0.5
			end
			throw "Didn't get redirected after confirming" if browser.current_url == url_prev

			puts "Got redirected to url: #{browser.current_url}"

			voucher_code = wait.until do
				el = browser.find_element(xpath: "//*[@id=\"thankyouTicket\"]/div/div[3]/div/p")
				el if el.text.split(" ")[1].to_i.to_s == el.text.split(" ")[1]
			end
			code = voucher_code.text.split(" ")[1..-1].join(" ")
			puts "Code: #{code}"
			puts "Done!"

			# this image is lazy loaded or some shit, really annoying and breaks ticket rect so we just get rid of it
			browser.execute_script("return document.getElementById('cardThankyou').childNodes[2].src = null")

			begin
				browser.save_screenshot(image_path)
				card_el = browser.find_element(xpath: "//*[@id=\"thankyouTicket\"]/div")
				card_rect = card_el.rect

				image = ChunkyPNG::Image.from_file(image_path)
				image.crop!(card_rect.x, card_rect.y, card_rect.width, card_rect.height-3)
				image.save(image_path)

				valid_until_el = wait.until do
					browser.find_element(xpath: "//*[@id=\"cardThankyou\"]/p/span[1]")
				end

				result[:message] = "**Successfully solved:**\nCode: `#{code}`\nValid until: #{valid_until_el.text.split("gültig bis: ")[1].split(" ")[0]}"
				result[:image] = image_path
				return result
			rescue => e
				result[:message] = "**Failed to save resulting image!**\nCode: `#{code}`\nToken: #{browser.current_url}\n#{generate_exception_message(e)}"
				result[:image] = image_path
				return result
			end
		rescue StandardError => e
			result[:message] = "**Uncaught error**\nURL: #{browser.current_url}\n#{generate_exception_message(e)}"
			result[:image] = browser.save_screenshot(image_path)
			return result
		end
	end
end

config = JSON.parse(File.read("config.json"), :symbolize_names => true)
Selenium::WebDriver::PhantomJS.path = File.expand_path(config[:phantomjs_path])
Telegram::Bot::Client.run(config[:telegram_token]) do |bot|
	puts "Bot logged in and started"

	Signal.trap("SIGINT") do
		puts "Quitting"
		Thread.kill Thread.current
	end

	bot.fetch_updates do |message|
		puts "[TG <] @#{message.chat.id}: #{message.text.inspect}"

		if message.text == "/start"
			text = "Your Chat ID is `#{message.chat.id}`."
			bot.api.send_message(chat_id: message.chat.id, text: text, parse_mode: "Markdown")
			puts "[TG >] @#{message.chat.id}: #{text.inspect}"

		elsif config[:telegram_users] == "*" || config[:telegram_users].include?(message.chat.id)
			code = message.text.chomp(" ")
			parts = code.split("-")
			if !parts.nil? && parts[0].length == 4 && parts[1].length == 4 && parts[2].length == 4 && !code.include?(" ")
				bot.api.send_message(chat_id: message.chat.id, text: "Attempting to solve survey with code `#{parts[0]}`**-**`#{parts[1]}`**-**`#{parts[2]}`. This might take a while...", parse_mode: "Markdown", reply_to_message_id: message.message_id)
				done = false

				Thread.new do
					loop do
						break if done
						bot.api.send_chat_action(chat_id: message.chat.id, action: "typing")
						sleep 4
					end
				end

				begin
					solver = McDonaldsSurveySolver.new
					result = solver.fetch_voucher("#{parts[0]}-#{parts[1]}-#{parts[2]}", config[:text_answer], config[:url])
					done = true

					log_url = nil
					message = result[:message]
					begin
						uri = URI.parse("https://hastebin.com/documents")
						http = Net::HTTP.new(uri.host, uri.port)
						http.use_ssl = true
						http.verify_mode = OpenSSL::SSL::VERIFY_NONE

						request = Net::HTTP::Post.new(uri.request_uri)
						request.body = solver.log

						# Send the request
						response = http.request(request)
						log_url = "https://hastebin.com/#{JSON.parse(response.body)["key"]}.txt"
					rescue StandardError => e
						puts "Uploading to hastebin failed: #{generate_exception_message(e)}"
					end

					message += "\n" + "Full log: #{log_url}" if !message.nil? && !log_url.nil?
					puts "[TG >] @#{message.chat.id}: #{message.inspect}"

					begin
						throw "no image" unless result.key? :image
						path = result[:image]
						path = path.path if path.is_a? File
						message_result = bot.api.send_photo(chat_id: message.chat.id, caption: message, parse_mode: "Markdown", photo: Faraday::UploadIO.new(path, 'image/png'))
						throw "upload failed" unless message_result["ok"]
					rescue StandardError => e
						bot.api.send_message(chat_id: message.chat.id, text: message, parse_mode: "Markdown")
					end

					solver.cleanup
				rescue => e
					puts "Generic error occurred while handling solve request: #{generate_exception_message(e)}"
				end
			else
				text = "That doesn't seem like a valid code. Example: `b10c-3yvd-0dus`"
				bot.api.send_message(chat_id: message.chat.id, text: text, parse_mode: "Markdown")
				puts "[TG >] @#{message.chat.id}: #{text.inspect}"
			end
		end
	end while true
end
