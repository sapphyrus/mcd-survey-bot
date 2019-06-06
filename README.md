# McDonalds survey bot
Get your free drinks for receipt codes faster. 🧾 🡢 🥤

# What the f*** is this about?
McDonald's germany currently has an offer where you can get a free drink or coffee after filling out a survey and entering a valid receipt code:

![preview image 2](https://i.imgur.com/3cQjqCZ.png)

This bot **fully automates** the tiresome process of doing that yourself, and instead lets you just send your receipt code to a telegram bot and spits out the voucher and code:

![preview image](https://i.imgur.com/6WCKahA.png)

Log file:
```
[14:34:36] Attempting to fetch voucher for b10c-3yvd-7dus, launching phantomjs
[14:34:55] Filling out form https://voice.fast-insight.com/s/7Rwd1/f/f37e23bcf43c73fbfc0f08e988f72b19?lang=de&timestamp=1559736180
[14:34:57] [20%] Answering 'Bitte beurteilen Sie Ihre Gesamtzufriedenheit basierend auf der Erfahrung Ihres letzten Besuches.' with 3 stars
[14:34:58] [22%] Answering 'Wie zufrieden waren Sie mit der Freundlichkeit unserer Mitarbeiter?' with 3 stars
[14:34:58] [27%] Answering 'Wie zufrieden waren Sie mit der Schnelligkeit unseres Services?' with 3 stars
[14:34:59] [31%] Answering 'Wie zufrieden waren Sie mit der Qualität der erhaltenen Speisen und Getränke?' with 5 stars
[14:35:00] [35%] Answering 'Wie zufrieden waren Sie mit der Sauberkeit des Restaurants?' with 3 stars
[14:35:00] [39%] Answering 'Wurde Ihre Bestellung ordnungsgemäß zusammengestellt und bearbeitet?' with 'Ja'
[14:35:00] [66%] Answering 'Basierend auf Ihrem Restaurantbesuch, wie wahrscheinlich würden Sie uns auf einer Skala von 0-10 an Freunde und Bekannte weiterempfehlen?' with '8'
[14:35:01] [70%] Answering 'Sie waren nicht ganz zufrieden mit uns, was könnten wir noch verbessern?' with 'Ich möchte darauf keine Auskunft sagen...'
[14:35:02] [75%] Answering 'Sie sind' with 'weiblich'
[14:35:02] [77%] Answering 'Bitte nennen Sie uns Ihr Alter:' with '20-29'
[14:35:03] [79%] Answering 'Für wie viele Personen, einschließlich Ihnen und all Ihren Begleitern/Innen, haben Sie heute bezahlt?' with '10 oder mehr'
[14:35:03] [81%] Answering 'Für wie viele Kinder (unter 14 Jahren) haben Sie heute bezahlt?' with '2'
[14:35:04] [83%] Answering 'Was war der Besuch bei McDonald's heute für Sie?' with 'nur ein Getränk'
[14:35:04] [83%] Didn't pass question, trying again
[14:35:04] [83%] Answering 'Was war der Besuch bei McDonald's heute für Sie?' with 'eine vollständige Mahlzeit'
[14:35:05] [85%] Answering 'Wie oft besuchen Sie ein McDonald's Restaurant?' with '1 Mal pro Woche oder öfter'
[14:35:05] [97%] Answering 'Bitte bestätigen Sie unsere Datenschutzbestimmungen.' with 'Ich stimme zu'.
[14:35:07] [100%] Done with questions.
[14:35:07] Survey filled out, confirming send.
[14:35:11] Got redirected to url: https://mcdonalds.fast-insight.com/voc/de/de/thankyou?token=eyJpdiI6IlwvWWN0bVwvRHdBSWhHSlFpdmUwajZSZz09IiwidmFsdWUiOiJjSWhOZnVmdlJGYkxmRVwvTythQ0lVd0k1a2s3OUZndE41S3Y4alM4ZG5Tbz0iLCJtYWMiOiIyZWZmNTViNzc5ZDdiMjJjNTMxOTM5OTRhNzk0NzYxYTBhZWU2ODA1Njg5ZGYyNjY5Mzg1OTZjYWIzMThjNDE0In0=&invoice=b10c3yvd7dus&store=132
[14:35:13] Code: 337109219
[14:35:13] Done!
```

# Installation
1. Install Ruby (2.5+, for Windows: https://rubyinstaller.org/)
2. Download phantomjs and put it in the bin/ directory (windows) or install it system wide (linux)
3. Message [@BotFather](https://t.me/@BotFather) on telegram and create a new bot
4. Rename `config.example.json` to `config.json` and open it with your text editor of choice
5. Replace `YOUR_TG_BOT_TOKEN` with your telegram bot token
6. Replace `YOUR_CHATID` with your chat id (`/start` the bot to display it) or set `telegram_users` to `"*"` to allow commands from all users
7. Send the bot a valid receipt code, it will then try to fill out the survey.
