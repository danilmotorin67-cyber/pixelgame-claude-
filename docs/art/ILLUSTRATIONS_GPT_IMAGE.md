# Иллюстрации «Солёного света» для GPT Image

Иллюстрации в игре — **не анимация**, а неподвижные картинки, которые идут одна за другой, как слайды:
титульный экран, 6 кадров пролога, 7 кадров финала, 12 гравюр к сказам Хельги, 8 афиш праздников,
8 фонов мини-игр, 28 слайдов эпилога и (по желанию) 24 наброска на страницах журнала Агаты —
всего 94 картинки. Каждая картинка — один промпт.

## Как работать

1. Откройте один чат и первым сообщением вставьте **«Стиль»** и **«Персонажи и места»** целиком
   (раздел ниже, по-английски) с просьбой держать их для всех следующих картинок.
2. Затем по одному отправляйте промпты из списка. Каждый промпт самодостаточен и заканчивается
   короткой строкой стиля — это страховка, если чат «забудет» начало.
3. Если персонаж получился не похожим — приложите к промпту его картинку из игры
   (`assets/sprites/portraits/<id>_neutral.png`, например `agatha_neutral.png`, `npc_stern_neutral.png`)
   и допишите «match this character's look».
4. **Герой.** Игрок выбирает внука или внучку, поэтому на картинках смотритель показан **со спины
   или издалека, волосы спрятаны под вязаной шапкой** — так кадр подходит обоим. Промпты уже так написаны.
5. **Размеры.**
   - Кадры на весь экран (титульник, пролог, финал, сказы, фоны мини-игр, эпилог): **1536×1024**
     (горизонтально). Я обрежу до 16:9 по центру — **важное держите в средней полосе по высоте**,
     сверху и снизу по ~80 px могут срезаться.
   - Афиши праздников: **1024×1536** (вертикально).
   - Наброски Агаты: **1024×1024**.
6. **Без текста.** Никаких надписей, букв, цифр, подписей, логотипов, рамок и водяных знаков —
   все тексты игра рисует сама. Если GPT вписал буквы — попросите перерисовать без них.
7. **Имена файлов** — по `id` из списка: `title.png`, `prologue_1.png`, … Сложите их в
   `assets_src/illustrations_gpt/` (или просто пришлите мне). Дальше я сам уменьшу их до сетки
   игры (480×270 для полноэкранных), сведу к палитре острова и подключу в игру.

---

## Стиль (вставить первым сообщением)

```
You will draw a series of illustrations for a cozy-melancholic pixel-art game "Salt Light"
("Солёный свет"). Keep ONE consistent style for every image in this chat:

STYLE
- Detailed 16-bit pixel art, like a hand-made game cutscene: crisp pixels, no blur, no gradients
  smoother than pixel dithering, clean dark outlines on characters, simple readable shapes.
- Palette: muted cold northern colours — slate-grey sea, basalt black rocks, moss green, lilac heather,
  pale fog, weathered wood; warm accents only from lamplight, fire and windows (amber, honey, ember).
- Mood: quiet, melancholic, warm-hearted; a northern fishing island where the sea keeps its dead.
- Light: soft overcast daylight or night lit by lanterns and the lighthouse; fog is common.
- Camera: cinematic wide shots, slight 3/4 top-down or eye level; characters small to medium in frame.
- NO text, NO letters, NO numbers, NO signatures, NO logos, NO frames, NO borders, NO watermarks.
  Signs and papers are blank or have unreadable scribbles.
- Keep important content inside the central band of the image (the top and bottom may be cropped).
```

## Персонажи и места (вставить сразу после стиля)

```
CHARACTERS (keep them recognisable in every image)
- The keeper (player): a young lighthouse keeper in a navy wool pea coat, long grey knitted scarf,
  dark trousers, brown boots, a dark knitted cap hiding the hair. ALWAYS shown from behind or from far
  away, face not visible (the player may be a man or a woman).
- Agatha Lind: old woman lighthouse keeper, about 70, long grey braid, yellow oilskin coat, carries an
  old brass lantern; kind, stubborn face. After her disappearance she appears pale and glowing faintly,
  like a lamp running out of oil.
- Stern: insurance director from the city, 49, tall and thin, black suit, black top hat, walking cane,
  cold thin smile.
- Halvdan Grim: village elder and merchant, 58, grey beard, fine brown wool coat, often holds a lantern;
  friendly on the surface, calculating eyes.
- Ingrid Grim: his daughter, 27, village teacher, neat blonde bun, grey wool dress, books in her arms.
- Olaf: postman and telegraphist, 24, round glasses, blue postal cap, leather satchel.
- Captain Grump: grumpy old skipper of the little steamer "Gull", captain's cap, huge grey moustache.
- Helga: tiny old storyteller woman, 97, many layered scarves, a bundle of herbs.
- Liv: naturalist, 26, long ginger braid, green field coat, binoculars.
- Tuve: a selkie girl in a grey sealskin cloak, long dark wet hair, grey eyes, barefoot.
- Fortuna: a carved wooden ship's figurehead of a maiden with a chipped nose and flaking gilt, hanging
  on the lighthouse wall; she can talk.
- Wick: the lighthouse cat — a sleek old black cat with yellow eyes.
- Rann: the sea goddess, vast, made of water and kelp, long flowing seaweed hair, calm glowing eyes.
- The Hmar: the youngest daughter of Rann, a weeping little girl made of lilac fog; also a lilac fog
  with pale sad faces in it.
- Rann's daughters: ethereal sea maidens of ripples, foam, breaking surf, frost, calm water, light
  (golden), tide (green-silver) and fog (lilac).

PLACES
- The Raven's Eye lighthouse: a tall white stone tower on a basalt cape, a keeper's cottage beside it,
  a small graveyard with wooden grave markers, a garden, heather and moss.
- Solvik: a small fishing village of tarred wooden houses with turf roofs, a pier, a chapel, a tavern.
- Kronvald: a rainy harbour city of grey stone, the office of "Neptune & Partners" insurance
  (a trident emblem).
- The steamer "Gull": small black passenger steamer with a red funnel.
- The Teeth: jagged black rocks in the sea; the Dead Fire: a rocky islet with an old dead signal
  fire basket and a stone crypt; Seal Rock; Old Solvik: a village drowned long ago, now under water.
- The Gates of the Deep: enormous ancient stone gates on the sea floor.
- The Halls of Rann: an undersea palace of fishing nets and bells, pale light.
```

---

## Список картинок

У каждой картинки — `id` (имя файла), что это в игре, и промпт. В конце каждого промпта строка
`Style: …` — её не убирайте.

### Титульный экран — 1 картинка, 1536×1024

**title** — главный экран игры, на нём потом будет название и меню (оставить тёмное небо сверху-слева
пустым под логотип).

```
The Raven's Eye lighthouse at night on a basalt cape, its warm beam sweeping through drifting fog over
a dark slate sea; the keeper's cottage below with one lit window; a tiny figure of the keeper with a
lantern on the path, seen from behind; stars above, heather in the foreground; empty dark sky in the
upper left for a title. Style: cozy-melancholic 16-bit pixel art, muted cold palette with warm lamplight,
no text.
```

### Пролог — 6 кадров, 1536×1024

Пролог «Письмо»: герой — клерк страховой конторы в столице, получает письмо о пропаже бабушки-смотрительницы
и уезжает на остров.

**prologue_1** — контора «Нептун и партнёры», дождь, на столе три страховых дела и штамп «ВЫПЛАТИТЬ».
```
Interior of a gloomy insurance office in a rainy harbour city: rows of desks, green-shaded lamps, tall
windows streaming with rain; the keeper sits at a desk from behind, a big rubber stamp raised over one of
three thick case folders; a trident emblem on the wall. Style: cozy-melancholic 16-bit pixel art, muted
cold palette with warm lamplight, no text.
```

**prologue_2** — мимо проходит Штерн: «Люди — это цифры, а цифры не тонут».
```
The same insurance office: Stern, a tall thin man in a black suit and top hat with a cane, walks past the
keeper's desk with a cold thin smile, glancing at the stamped folders; a clerk bows his head; rain on the
windows. The keeper is seen from behind. Style: cozy-melancholic 16-bit pixel art, muted cold palette with
warm lamplight, no text.
```

**prologue_3** — два письма: официальное от Лоцманской управы и написанное рукой Агаты «Ключ — под кошкой».
```
Close-up of a desk under a green lamp: two opened letters — a stiff official letter with a wax seal and
a small handwritten letter with a tiny drawing of a lighthouse and a black cat in the corner; the keeper's
hands hold them; an old photograph of a smiling old woman keeper in a yellow oilskin lies beside.
Handwriting is unreadable scribbles. Style: cozy-melancholic 16-bit pixel art, muted cold palette with
warm lamplight, no text.
```

**prologue_4** — разговор со Штерном: «Вы куда-то собрались?»
```
Stern stands in the doorway of his dark office, one eyebrow raised, leaning on his cane; the keeper stands
before him from behind, a travel bag in hand; a model sailing ship on the shelf, rain behind the window.
Style: cozy-melancholic 16-bit pixel art, muted cold palette with warm lamplight, no text.
```

**prologue_5** — анкета смотрителя: имя, родство и странная графа «Что вы любите больше всего?».
```
A lighthouse keeper's application form lying on a table next to a fountain pen, an old brass key, a
folded map of an island and a steaming cup of tea; the form has blank lines and unreadable scribbles;
warm lamplight, rain-dark window. Style: cozy-melancholic 16-bit pixel art, muted cold palette with warm
lamplight, no text.
```

**prologue_6** — пароход «Чайка» в тумане, причал Сольвика в 17:00: Хальвдан протягивает корзину, Олаф — «Устав смотрителя».
```
The small black steamer "Gull" with a red funnel moored at a wooden pier of a fishing village in evening
fog; Captain Grump with a huge moustache at the rail; on the pier Halvdan (grey beard, brown coat) holds out
a basket of bread and seeds, Olaf (round glasses, postal cap) offers a book; the keeper with a suitcase,
seen from behind; the lighthouse faint on a far cape. Style: cozy-melancholic 16-bit pixel art, muted cold
palette with warm lamplight, no text.
```

### Финал «Великий Прилив» — 7 кадров, 1536×1024

**finale_1** — держать огонь: буря, маяк горит, по лестнице лезут диверсанты, мимо проходит лайнер «Королева Кронвальда».
```
A raging night storm: the Raven's Eye lighthouse blazing, its beam cutting the rain; dark hooded saboteurs
climbing the outside stair of the tower; huge waves breaking on the basalt; far out a big white passenger
liner with two funnels passes safely by the light. Style: cozy-melancholic 16-bit pixel art, muted cold
palette with warm lamplight, no text.
```

**finale_2** — 01:00, море уходит: мокрое дно, лужи с рыбами, остовы кораблей в иле, над всем кружит Хмарь.
```
The sea drawn far out at night under a full moon: wet sand and silt shining all the way to the horizon,
tide pools with flapping fish, the ribs of old shipwrecks sticking out of the mud, a lilac fog circling
overhead; the keeper with a lantern walks down from the cape onto the seabed, seen from behind. Style:
cozy-melancholic 16-bit pixel art, muted cold palette with warm lamplight, no text.
```

**finale_3** — у Врат Глуби горит фонарь: там ждёт Хальвдан.
```
Enormous ancient stone gates standing on the exposed sea floor, carved with waves and nine women; before
them Halvdan in his brown coat holds up a lantern and smiles a thin smile; the keeper approaches from the
foreground, seen from behind; kelp and wreck ribs around, moonlight. Style: cozy-melancholic 16-bit pixel
art, muted cold palette with warm lamplight, no text.
```

**finale_4** — Хальвдан бросается столкнуть героя во Врата; волна вырывает фонарь, и оба падают.
```
Dramatic moment at the Gates of the Deep: a huge dark wave bursts through the open gates, tearing the
lantern from Halvdan's hand; Halvdan and the keeper fall into the glowing blue depths beyond the gates,
the lantern spinning away; spray and bubbles. Style: cozy-melancholic 16-bit pixel art, muted cold palette
with warm lamplight, no text.
```

**finale_5** — Чертоги Ранн: дворец из сетей и колоколов, здесь можно дышать.
```
The Halls of Rann: a vast undersea palace woven of old fishing nets and hung with hundreds of ship bells,
pale green-blue light filtering down, drowned lanterns floating, schools of silver fish; the keeper, small,
stands in the middle looking up, seen from behind, a glowing charm of gills at the neck. Style:
cozy-melancholic 16-bit pixel art, muted cold palette with warm lamplight, no text.
```

**finale_6** — Агата, слабая, светится как догорающий фонарь; за ней прячется Хмарь — плачущая девочка из тумана.
```
In the Halls of Rann: Agatha, the old keeper with a long grey braid and yellow oilskin, pale and glowing
faintly like a lamp running out of oil, smiles tiredly and holds out her hand; behind her hides the Hmar,
a small weeping girl made of lilac fog; the keeper in the foreground, seen from behind. Style:
cozy-melancholic 16-bit pixel art, muted cold palette with warm lamplight, no text.
```

**finale_7** — Ранн поднимается из глубины: «Выбирай, смотритель».
```
Rann the sea goddess rises from the depths, immense and calm, made of water and kelp, seaweed hair flowing,
glowing eyes; before her float four faint paths of light in different colours; tiny Agatha and the fog girl
beside the keeper, who stands small in the foreground seen from behind. Style: cozy-melancholic 16-bit pixel
art, muted cold palette with warm lamplight, no text.
```

### Сказы Хельги — 12 гравюр, 1536×1024

Эти картинки — **в другом стиле**: старые гравюры, их Хельга «показывает», пока рассказывает.
Добавьте перед первым сказом: «For the next 12 images switch the style to old sepia woodcut engravings».

**tale_1** — «Как Ранн пришла за солью»: море было пресным; Ранн потеряла девять дочерей в один шторм и плакала сто лет — море стало солёным.
```
A huge sorrowful sea woman made of waves weeps into the ocean, her tears falling like salt rain, tiny
fishing boats below. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching,
folk-tale illustration in pixel art, no text.
```

**tale_2** — «Девять дев»: дочери вернулись к Ранн погодой; девять камней на пустоши — их кресла.
```
Nine standing stones on a heather moor, on each sits a ghostly maiden made of weather — swell, foam, surf,
frost, calm, light, tide, fog. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine
hatching, folk-tale illustration in pixel art, no text.
```

**tale_3** — «Первый огонь»: первый смотритель пришёл на мыс с одним фонарём и не стал бороться с Хмарью, а спросил Ранн, чего она хочет.
```
The first keeper with a single lantern stands on a bare cape facing a wall of fog; a great sea woman rises
from the waves to listen. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching,
folk-tale illustration in pixel art, no text.
```

**tale_4** — «Кривой фонарь Грима»: человек с кривым фонарём заманивал корабли на скалы.
```
A wrecker on the rocks at night swings a crooked lantern, luring a sailing ship onto jagged black rocks.
Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching, folk-tale illustration
in pixel art, no text.
```

**tale_5** — «Ночь Большой Воды»: Уговор нарушен, море за ночь поднялось на три дома, Старый Сольвик ушёл под воду.
```
A village flooded in one night: the sea rising over the roofs, a bell tower half under water, people
escaping in boats. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching,
folk-tale illustration in pixel art, no text.
```

**tale_6** — «Слова Уговора»: «Я держу огонь для живых. Ты держишь воду для мёртвых».
```
A keeper and a woman made of waves clasp hands over a round stone, a ribbon of light winding around them
like an oath. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching,
folk-tale illustration in pixel art, no text.
```

**tale_7** — «Кот, который не утонул»: в Ночь Большой Воды кот уплыл на двери и добрался до мыса.
```
A black cat sailing on a floating wooden door across a stormy sea toward a lighthouse on a cape. Style: old
woodcut engraving printed in sepia ink on yellowed paper, fine hatching, folk-tale illustration in pixel art,
no text.
```

**tale_8** — «Шелки Тюленьего камня»: в полнолуние тюлени сбрасывают шкуры и сидят на камне девушками.
```
Seals on a rock under a full moon; some have shed their skins and sit as girls combing their hair; a man
hides behind the rocks clutching a stolen sealskin. Style: old woodcut engraving printed in sepia ink on
yellowed paper, fine hatching, folk-tale illustration in pixel art, no text.
```

**tale_9** — «Звонарь»: звонарь Старого Сольвика звонил, пока вода не сомкнулась над колокольней.
```
A bell ringer pulls the rope in a belfry while the flood rises around the tower; people in boats row away
toward the hills. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching,
folk-tale illustration in pixel art, no text.
```

**tale_10** — «Почему плачет туман»: Хмарь — младшая дочь, её так и не нашли; она ищет всех непогребённых.
```
A weeping young girl made of fog wanders over a night sea, searching among floating wreckage, her hands
outstretched. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine hatching, folk-tale
illustration in pixel art, no text.
```

**tale_11** — «Великий Прилив»: раз в пятьдесят лет Ранн делает вдох, вода уходит до самых Зубов, открываются Врата Глуби.
```
The sea drawn back to the horizon, the jagged Teeth rocks bare, enormous gates opening on the sea floor,
a single walker with a lantern approaching them. Style: old woodcut engraving printed in sepia ink on yellowed
paper, fine hatching, folk-tale illustration in pixel art, no text.
```

**tale_12** — «Последний сказ»: Агате двадцать, первая вахта, шторм, Хмарь, и никого рядом; она всю ночь пела у огня.
```
A young woman keeper of twenty with a long braid sings at the lamp of a lighthouse through a stormy night,
alone, fog pressing at the windows. Style: old woodcut engraving printed in sepia ink on yellowed paper, fine
hatching, folk-tale illustration in pixel art, no text.
```

### Афиши праздников — 8 штук, 1024×1536 (вертикально)

Внизу афиши оставьте **пустую светлую полосу** — туда игра впишет название и дату. Перед первой
афишей: «Now switch to a vintage village festival poster style».

| id | праздник | промпт |
|---|---|---|
| poster_boat_blessing | Спуск лодок, весна 13 | `Vintage festival poster: small fishing boats decorated with ribbons and flowers sliding down a slipway into a spring sea, a priest blessing them, villagers cheering; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_bird_day | Птичий день, весна 24 | `Vintage festival poster: puffins, gulls and guillemots over tall sea cliffs, villagers on ropes collecting eggs, a naturalist with binoculars; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_white_sun | Ночь Белого Солнца, лето 11 | `Vintage festival poster: a midsummer bonfire on a heather moor under the midnight sun, people dancing in a ring around nine standing stones; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_regatta | Регата, лето 25 | `Vintage festival poster: small sailboats racing around a seal rock on a bright summer sea, flags on a crowded pier; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_herring_fair | Сельдяная ярмарка, осень 16 | `Vintage festival poster: an autumn harbour fair with barrels of herring, stalls, bunting and lanterns, a man throwing a boot; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_drowned_night | Ночь Утопленников, осень 27 | `Vintage festival poster: paper lanterns floating on dark water at night, villagers on the shore remembering the drowned, faint friendly ghosts among them; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_ice_festival | Праздник льда, зима 8 | `Vintage festival poster: a frozen lagoon with skaters, ice-fishing holes and ice sculptures, a swordfish frozen in a block of ice; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |
| poster_long_night | Долгая ночь, зима 25 | `Vintage festival poster: the longest winter night, a tavern glowing warm in the snow, a lighthouse hung with garlands, the aurora above; a blank light band at the bottom. Style: vintage village poster in pixel art, bold simple shapes, warm paper colours, no text.` |

### Фоны мини-игр праздников — 8 штук, 1536×1024

Это **фон**, поверх которого игра рисует полоски, стрелки и счёт. Поэтому: спокойная сцена,
**пустой передний план и середина**, без людей в центре, ничего мелкого и яркого посередине.
Вернитесь к основному стилю: «Switch back to the main pixel-art style».

| id | мини-игра | промпт |
|---|---|---|
| minigame_boat_blessing | «Бег с веслом» по причалу | `Background scene: a long wooden pier of a fishing village on a spring morning, decorated boats moored along it, bunting overhead, the middle of the pier empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_bird_day | Сбор яиц на верёвках | `Background scene: a tall sea cliff face with ledges full of nesting seabirds, ropes hanging down from the top, sea far below, the centre of the cliff empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_white_sun | Танец в полночь | `Background scene: a heather moor under the pale midnight sun, a ring of nine standing stones with a bonfire, trampled grass in the middle empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_regatta | Гонка под парусом | `Background scene: open summer sea seen from above at a slight angle, a seal rock with buoys around it, gentle waves, the water in the middle empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_herring_fair | Чистка сельди, метание сапога, «Угадай вес» | `Background scene: an autumn harbour square with market stalls and herring barrels at the edges, lanterns and bunting, the cobbled middle empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_drowned_night | Фонарики по воде | `Background scene: dark calm bay at night, a few paper lanterns floating near the shore, the village lights far away, the water in the middle dark and empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_ice_festival | Подлёдный лов, коньки | `Background scene: a frozen lagoon under a pale winter sky, snowy shores and a few ice sculptures at the edges, smooth empty ice in the middle. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |
| minigame_long_night | Общий ужин, тайный даритель | `Background scene: the warm interior of a village tavern on the longest night, a long table at the edges with candles, garlands, snow at the windows, the floor in the middle empty. Wide calm composition with an empty centre for game UI. Style: cozy-melancholic 16-bit pixel art, muted cold palette, no text.` |

### Эпилог — 28 слайдов, 1536×1024

Эпилог — это 6–8 слайдов по итогам игры. Какие именно покажутся — зависит от выборов игрока,
поэтому нужны все варианты. Вернитесь к основному стилю.
Строка стиля для всех слайдов: `Style: cozy-melancholic 16-bit pixel art, muted cold palette with warm lamplight, no text.`

**Концовка (одна из четырёх)**

| id | что сказано в игре | промпт |
|---|---|---|
| epilogue_ending_a | «Новый Уговор»: по утрам над мысом «Утренняя дымка», рыбаки говорят — на удачу; Ночей Хмари больше нет | `A soft golden morning mist over the cape and the calm sea, fishermen in boats smiling and waving at the lighthouse, the keeper on the cliff seen from behind. + style` |
| epilogue_ending_b | «Цена света»: Агата живёт в вахтенной, критикует огород и обыгрывает героя в рыбалке | `Agatha, alive, in her yellow oilskin, sits on the lighthouse steps pointing critically at a vegetable garden, a fishing rod beside her and a bucket full of fish; the keeper stands nearby seen from behind. + style` |
| epilogue_ending_c | «Разорванный уговор»: нет туманов и призраков; море молчит | `A perfectly clear, cold, windless sea, no fog, no birds, the lighthouse dark in daylight, an empty silent shore, a sense of something missing. + style` |
| epilogue_ending_d | «Отложенный уговор»: Агата держит дверь ещё год, герой держит огонь | `Split composition: above, the lighthouse lamp blazing at night with the keeper beside it seen from behind; below the waterline, faint Agatha holding a great door shut in the deep. + style` |

**Суд над «Нептуном» (один из шести)**

| id | в игре | промпт |
|---|---|---|
| epilogue_court_trial | Суд: «Нептун» разорён, артель Сольвика платит честно | `A small harbour courtroom, a judge's gavel coming down, fishermen cheering, Stern with his top hat in his hands looking defeated. + style` |
| epilogue_court_arrest | Хальвдан в тюрьме; Штерн где-то в Кронвальде открывает новую контору | `Halvdan behind prison bars looking at the sea through a small window; through a rainy city window far away a tall man in a top hat hangs up a new sign (blank). + style` |
| epilogue_court_fled | Шляпа Хальвдана на полке в таверне, её никто не трогает | `A warm village tavern, a brown felt hat lying alone on a shelf above the bar, villagers glancing at it and leaving it be. + style` |
| epilogue_court_pardon | На Мёртвом Огне горит свет — настоящий; Хальвдан протирает стёкла | `The rocky Dead Fire islet at dusk with a small old signal lamp shining truly again; Halvdan, older and humbled, wipes its glass with a rag. + style` |
| epilogue_court_taken | Коллекция Гримов у Ранн полна; Ингрид ставит отцу камень | `Ingrid in her grey dress places a simple stone on a grave on a windswept hill above the sea, her books set aside on the grass. + style` |
| epilogue_court_none | Остров живёт дальше | `The fishing village on an ordinary morning: smoke from chimneys, boats going out, children running on the pier. + style` |

**Фортуна (один из четырёх)**

| id | в игре | промпт |
|---|---|---|
| epilogue_fortuna_stays | Фортуна остаётся голосом маяка и напоминает обо всём | `The carved wooden figurehead Fortuna on the lighthouse wall, smiling and talking, the keeper listening with a cup of tea, lamplight. + style` |
| epilogue_fortuna_released | Фортуна молчит и улыбается | `The figurehead Fortuna silent on the wall with a peaceful smile, a beam of morning sun across her chipped wooden face. + style` |
| epilogue_fortuna_rests | Фортуна спит; иногда поскрипывает во сне | `The figurehead Fortuna with closed eyes, asleep, moonlight and dust motes in the quiet lighthouse room, the black cat asleep below her. + style` |
| epilogue_fortuna_silent | Фортуна ворчит, что «Элеонору» так и не нашли | `The figurehead Fortuna frowning grumpily toward a window with the foggy sea, where a faint green ghost ship is barely visible. + style` |

**Двадцать безымянных (один из двух)**

| id | в игре | промпт |
|---|---|---|
| epilogue_twenty_done | На погосте двадцать новых имён; судовая роль «Фортуны» в рамке | `The small graveyard on the cape with twenty new wooden grave markers in neat rows, heather and candles, a framed old ship's roll hanging in the lighthouse window behind (unreadable). + style` |
| epilogue_twenty_waiting | В Зале Двадцати всё ещё слишком тихо | `A dim underground hall with twenty empty stone niches, dust in a single beam of light, a feeling of waiting. + style` |

**Туве (один из трёх, если игрок её встретил)**

| id | в игре | промпт |
|---|---|---|
| epilogue_tuve_stays | Туве осталась; в полнолуние уходит в море и всегда возвращается | `Tuve in her grey sealskin cloak walks into the sea under a full moon, looking back with a smile toward a warm lit cottage. + style` |
| epilogue_tuve_left | Туве уплыла; иногда на Тюленьем камне сидит серая тюлениха и смотрит на деревню | `A grey seal with human-like grey eyes sits on Seal Rock looking toward the distant village. + style` |
| epilogue_tuve_sea | Тюлени у камня ждут свою девушку в сером | `Seals resting on Seal Rock at dusk, one empty place among them where a grey sealskin lies folded. + style` |

**Туманники, община (один из трёх)**

| id | в игре | промпт |
|---|---|---|
| epilogue_community_all | Летними ночами над мысом светятся светлячки — бывшие Туманники | `A summer night over the cape, hundreds of soft fireflies glowing above the grass and the graveyard, the lighthouse beam above. + style` |
| epilogue_community_some | Туманники чинят, что им доверили, и ждут остального | `Faceless hooded figures made of grey mist mending a fishing boat and a fence at dusk, quietly working. + style` |
| epilogue_community_none | Гильдейский дом стоит пустой, туман в окнах | `An empty old guild house in the village, fog drifting out of its dark windows, the door ajar. + style` |

**Путь «Нептуна» (один из четырёх)**

| id | в игре | промпт |
|---|---|---|
| epilogue_neptune_signed | Консервный завод дымит в Бухте; море хмурится | `A grim fish cannery of corrugated iron smoking in a bay, grey foamy water, dark clouds gathering over the sea. + style` |
| epilogue_neptune_annulled | Завод закрыт после «похорон»; остров смеётся | `A closed cannery with boarded windows and a funeral wreath on the door, villagers laughing in front of it. + style` |
| epilogue_neptune_torn | Порванный договор в рамке на стене таверны | `A torn document with a trident seal framed on the wall of the village tavern, villagers raising mugs beneath it (unreadable text). + style` |
| epilogue_neptune_never | «Нептун» так и не пустил корней на острове | `An unspoiled bay with fishing boats and drying racks, no factory, gulls and a calm sea. + style` |

**Семья (если есть)**

| id | в игре | промпт |
|---|---|---|
| epilogue_spouse | Супруг(а) держит огонь вместе с героем | `Two figures side by side at the great lighthouse lamp at night, seen from behind, the beam going out over the sea. + style` |
| epilogue_children | Дети спрашивают на погосте: «А мы тоже станем знаками?» | `Two small children in knitted hats standing among wooden grave markers on the cape, looking up curiously at an adult seen from behind. + style` |

`+ style` в таблицах = допишите строку стиля эпилога из начала раздела.

### Наброски в журнале Агаты — 24 штуки, 1024×1024 (по желанию)

Маленькие рисунки на полях страниц журнала. Перед первым: «Now switch to quick ink sketches».
Строка стиля: `Style: quick ink sketch in brown ink on off-white paper, a few pale watercolour washes, loose hand-drawn lines rendered as pixel art, plain paper background, no text.`

| id | страница журнала | промпт |
|---|---|---|
| page_1 | первый день её вахты: «Огонь зажжён. Кот уже был здесь» | `A lighthouse lamp just lit, a black cat sitting beside it. + style` |
| page_2 | «Где Ф — там ещё двадцать» | `A carved ship's figurehead of a maiden, a question mark drawn beside it in ink. + style` |
| page_3 | девять камней, три светятся | `Nine standing stones on a moor, three of them shaded as if glowing. + style` |
| page_4 | крушения только в ясные ночи | `A starry clear night over sharp sea rocks with a small sinking ship. + style` |
| page_5 | «Водоросли помнят улицы Старого Сольвика» | `Rows of kelp growing under water in straight lines like streets of houses. + style` |
| page_6 | «Х. опять уходил ночью без фонаря» | `An empty rowing boat pulled up on the shore at dawn, footprints leading away. + style` |
| page_7 | «Кай видел огонь. Кай испугался» | `A frightened man with wild hair staring at a distant fire. + style` |
| page_8 | слова Уговора | `A round stone broken into three pieces. + style` |
| page_9 | ночь гибели команды Хедды: второй огонь на Зубах | `Two fires burning at night: one on a lighthouse, one on jagged rocks. + style` |
| page_10 | красный сектор линзы над Зубами | `A lighthouse lens with one red sector shaded. + style` |
| page_11 | фреска Уговора в крипте | `A fresco of a keeper with a lantern, a woman of waves and a stone broken in three between them. + style` |
| page_12 | «Люди „Нептуна“ снова на острове» | `Two men in bowler hats with briefcases standing on a pier. + style` |
| page_13 | шхуна «Ласточка» — Зубы | `A schooner wrecked on jagged rocks under a clear sky. + style` |
| page_14 | бриг «Верность» — Зубы, застрахован за неделю | `A brig sinking by sharp rocks, a small trident mark in the corner. + style` |
| page_15 | «Надежда Кронвальда» — Зубы; страховщик «Нептун», опять | `A ship breaking on rocks, a large trident mark drawn beside it and circled. + style` |
| page_16 | «кто-то светит ярче меня» | `A lighthouse with a second, brighter false light on the rocks, arrows and sums scribbled around (unreadable). + style` |
| page_17 | «Олаф выучил морзянку за одну зиму» | `A telegraph key with dots and dashes drawn beside it. + style` |
| page_18 | узор свитера; «Маргит, прости за сковородку» | `A knitted sweater pattern and a frying pan. + style` |
| page_19 | колокол Старого Сольвика звонил, пока вода не сомкнулась | `A bell tower under water with a small figure still ringing the bell. + style` |
| page_20 | «Камень. Третья часть — их» | `One third of a broken stone, shaded carefully. + style` |
| page_21 | её спуск: «Здесь холодно, но я слышу её» | `A small figure with a lantern descending into dark water. + style` |
| page_22 | письмо Фортуне | `A carved figurehead of a maiden with a letter tucked beside her. + style` |
| page_23 | «Я держу дверь. Держи огонь» | `A figure holding a heavy door shut under the sea. + style` |
| page_24 | последнее письмо: «Ещё год. Я держусь» | `A candle almost burnt down beside a folded letter. + style` |

---

## Что я сделаю с готовыми картинками

- Обрежу полноэкранные до 16:9, уменьшу до 480×270 (крупный пиксель, как в игре) и сведу к палитре
  острова; афиши — до 160×240, наброски — до 64×64.
- Подключу: титульник за меню, пролог и финал — картинка на весь экран с текстом сцены внизу,
  гравюры — в окне сказа Хельги, афиши — на доске праздника, фоны — под мини-игрой, слайды эпилога — по
  итогам игры, наброски — на страницах журнала Агаты.
