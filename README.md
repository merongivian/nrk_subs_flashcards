# A.K.A Hopefully this will motivate me to learn more norwegian 😁

Ruby script that generates flashcards with translations of subtitles for NRK tv shows. Flashcards powered by ANKI.

Lets say we want to generate flashcards for Skam, season two, episode one, u just run this in the console:

```
ruby anki_nrk.rb skam 2 1
```
(if the show has more that one word u just write it like this, for example for them 'Hvem bor her?' show: hvem-bor-her)

This will generate this file, that you can load on ANKI:

```
skam_2_1.dpkg
```

Translations rely on google translations api unfortunately 😑, so you have to set the key in an .env file:

```
GOOGLE_TRANSLATIONS_API_KEY=my key
```
