# Projektplan

## 1. Projektbeskrivning (Beskriv vad sidan ska kunna göra)
* På sidan ska användare lägga upp annonser på varor som de säljer.
* De ska kunna kolla på specifika annonser samt ge säljaren ett betyg från 0 till 5
## 2. Vyer (visa bildskisser på dina sidor)
Skiss på landingpage
![Skiss framsida](https://i.imgur.com/I6jGW0l.png)

Skiss på en enstaka ad
![Skiss på annons](https://i.imgur.com/YjhzG6k.png)
## 3. Databas med ER-diagram (Bild)
![ER-diagram](https://github.com/itggot-daniel-persson/storprojekt20/blob/master/ER-Diagram.png?raw=true)
## 4. Arkitektur (Beskriv filer och mappar - vad gör/inehåller de?)
Mappar:
public - Innehåller alla publika filer
* js 
* img - Innehåller en undermapp med alla annons bilder
  * ads_img
* css - Innehåller stilarket av sidan

views - Innehåller alla restful routes slim filer
* admin - Innehåller slim filer för admin relaterade händelser
* ads - Innehåller slim filer för annons relaterade händelser
* users - Innehåller slim filer för användar relaterade händelser

Filer:
app.rb - Huvuddelen i projektet där alla routes finns
model.rb - Inehåller alla databas förfrågningar + validering av information
