# Музыка и звуки «Солёного света» для ElevenLabs

Всё аудио игры: 34 музыкальных трека, 2 слоя поверх музыки, 11 атмосфер (фоновых петель) и звуки. Игра уже
знает каждый id из этого списка. Как только файл с таким именем появится, он заиграет сам: в нужном месте,
в нужное время суток, с плавным переходом. Пока файла нет, на его месте тишина.

## Как работать

1. **Музыка** — в Eleven Music (Text to Music):
   - вставьте **«Стиль саундтрека»** (ниже) в начало каждого промпта, затем промпт трека;
   - везде ставьте «instrumental / без вокала»; хоровое мычание без слов допустимо там, где оно указано;
   - длительность — как в таблице. Длинные треки звучат по кругу, 2–3 минуты хватает.
2. **Атмосферы и звуки** — в Sound Effects:
   - атмосферы по 20–30 с, с галочкой Loop, если она есть;
   - звуки 0,3–2 с. Сгенерируйте 2–4 варианта и оставьте лучшие.
3. **Имена файлов** — по id из таблиц:
   - например `cape_spring.mp3`, `amb_sea.mp3`, `pick_stone.mp3`;
   - несколько вариантов одного звука называйте `pick_stone_1.mp3`, `pick_stone_2.mp3`… Игра будет
     выбирать между ними случайно.
4. **Куда класть** — в `assets_src/audio/music/`, `assets_src/audio/ambience/`, `assets_src/audio/sfx/`,
   или просто пришлите мне.
5. **Дальше делаю я** (`tools/audio_loop.py`):
   - обрежу тишину и выровняю громкость (музыка около −16 LUFS, атмосферы тише, пики звуков −6 dBFS);
   - склею петлю без шва;
   - если у трека есть вступление, поставлю начало петли на первый такт после него.
6. **Лицензия.** Проверьте, что тариф разрешает коммерческое использование. В Steam ИИ-аудио указывается в
   раскрытии про ИИ.

## Стиль саундтрека (вставлять в начало каждого музыкального промпта)

```
Instrumental soundtrack for a cozy-melancholic pixel-art game about a lighthouse keeper on a cold northern
fishing island. Nordic acoustic folk with chamber colours: Hardanger-style fiddle, cello, drone strings,
accordion, tin whistle, plucked nyckelharpa or cittern, frame drum, soft bells, glass harmonica, distant
wordless low male choir humming. Warm but melancholic, intimate, natural room sound, no modern synths,
no electronic beats, no vocals with words. Suitable as a seamless looping background track: steady energy,
no fade-in, no fade-out, no big ending.
```

## Музыка — 34 трека

| id | Где звучит | Длит. | Промпт (после стиля) |
|---|---|---|---|
| `main_theme` | Меню, титры | 2:30 | Main theme "Salt Light". Solo fiddle states a simple, singable melody in D Dorian, cello answers; drone strings under; later accordion joins softly. 72 bpm. Nostalgic, hopeful, like a lamp in the fog. |
| `kronvald` | Пролог (город, контора) | 2:00 | Rainy harbour city office. Clarinet melody over a dry typewriter-like rhythm of muted plucks and soft woodblock, pizzicato strings, rain-like shaker. 90 bpm, A minor. Grey, busy, a little absurd. |
| `cape_spring` | Мыс и остров днём, весна | 2:30 | Spring morning on a windy cape. Tin whistle melody and bright plucked strings, light frame drum, G major, 96 bpm. Fresh, new beginnings, seabirds' mood. |
| `cape_summer` | …лето | 2:30 | Summer waltz on the cape. Accordion waltz in 3/4, D major, 88 bpm, fiddle countermelody, gentle guitar-like plucks. Warm light evenings. |
| `cape_autumn` | …осень | 2:30 | Autumn on the cape. Slow fiddle melody over a cello drone, E minor, 76 bpm, sparse plucks like falling leaves. Wistful, windy. |
| `cape_winter` | …зима | 2:30 | Winter on the cape. Glass harmonica and small bells, A minor, 60 bpm, very sparse, cold air, soft low drone. Quiet, frozen, still beautiful. |
| `village_spring` | Деревня днём, весна | 2:30 | Fishing village theme, spring arrangement. Lively cittern and whistle, light frame drum, G major, 100 bpm, friendly and busy. |
| `village_summer` | …лето | 2:30 | Same fishing village theme, summer arrangement: accordion lead, fiddle harmony, D major, 100 bpm, sunny market day. |
| `village_autumn` | …осень | 2:30 | Same fishing village theme, autumn arrangement: fiddle and cello, E minor, 92 bpm, herring season, a bit tired but warm. |
| `village_winter` | …зима | 2:30 | Same fishing village theme, winter arrangement: accordion and bells, A minor, 84 bpm, smoke from chimneys, cosy. |
| `tavern` | Таверна «Сухой Утопленник» | 2:00 | Tavern jig, 120 bpm, D major, accordion and whistle, stomping frame drum, muffled like heard in a warm crowded room. |
| `tavern_fiddle` | Таверна, суббота вечером (после квеста скрипки Иона) | 2:00 | Same tavern jig but led by a virtuosic ghostly fiddle, slightly eerie ornaments, 124 bpm. |
| `night` | Суша ночью | 3:00 | Night on the island. Soft sustained string pads, a distant low horn, sparse harp-like plucks, 60 bpm, D minor. Calm, lonely, stars and surf. |
| `watch` | Фонарная маяка | 2:30 | The lantern room at night: the main theme melody played on a music box, slow clockwork ticking as rhythm, warm low drone. 72 bpm, D Dorian. |
| `graveyard` | Погост, часовня | 2:30 | Island graveyard. Wordless low male choir humming, solo cello, rare bell notes, D minor, 56 bpm. Respectful, peaceful grief. |
| `hmar` | Ночи Хмари на суше | 2:30 | Supernatural fog night. Detuned glass harmonica, reversed choir swells, slow heartbeat pulse, no clear key, unsettling but not horror. |
| `rowing` | Море, на вёслах | 2:30 | Rowing a small boat. Steady rhythm like oar strokes on frame drum and low strings, 84 bpm, fiddle melody, A minor, determined. |
| `sailing` | Море, под парусом | 2:30 | Sailing with the wind. Wide sweeping strings and soaring fiddle, 100 bpm, D major, open sea freedom. |
| `storm` | Море в шторм | 2:00 | Storm at sea. Driving drums, tremolo fiddles, cello ostinato, 130 bpm, D minor, urgent and dangerous. |
| `grottoes` | Гроты Отлива | 2:30 | Sea caves at low tide. Dripping water as rhythm, wooden percussion, low drone, sparse plucks, mysterious, 80 bpm. |
| `deep_kelp` | Глубь: Кельповый лес | 2:30 | Underwater kelp forest. Dreamy, muffled, slow harp and glass harmonica, soft pads, gentle bubbles feel, 70 bpm. |
| `deep_old_solvick` | Глубь: Старый Сольвик | 2:30 | A drowned village. Muffled church bells under water, organ-like pads, sad slow melody, 66 bpm. |
| `deep_bone_abyss` | Глубь: Костяная Бездна | 2:30 | The deepest abyss. Very low drones, distant whale-like calls, slow pulse, dark and vast, 60 bpm. |
| `boss_mother_moray` | Босс: Мать-Мурена | 2:00 | Boss fight with a giant moray eel. Tense rhythmic strings, sharp fiddle stabs, frame drums, 140 bpm, C minor. |
| `boss_bell_ringer` | Босс: Звонарь | 2:00 | Boss fight with a drowned bell ringer. Bells used as percussion, low choir chanting without words, 132 bpm, ominous. |
| `boss_bone_whale` | Босс: Костяной Кит | 2:00 | Epic boss fight with a whale skeleton. Low brass-like strings, big drums, full wordless choir, 120 bpm, D minor. |
| `festival` | Праздники в деревне | 2:30 | Village festival. Joyful folk dance, fiddle and accordion together, clapping-like percussion, 116 bpm, G major. |
| `drowned_night` | Праздник «Ночь Утопленников» | 2:30 | Night of the Drowned festival. Slow bittersweet waltz in 3/4, fiddle and cello, candles on water, 72 bpm, E minor. |
| `loss` | Грустные сцены | 1:30 | Loss. Solo cello, slow, D minor, 54 bpm, very simple and tender. |
| `mystery` | Расследование, доска улик | 2:00 | Investigation. Pizzicato strings and clarinet, curious and sly, 92 bpm, E minor. |
| `hold_the_fire` | Финал, фаза 1 | 2:00 | Finale: keep the lighthouse burning through the great storm. Pressing, heroic, driving drums and strings, main theme fragments, 140 bpm. |
| `seabed_path` | Финал, фаза 2 | 2:00 | Finale: walking the path on the sea floor. Almost silence, slow heartbeat, distant choir, a few glass notes. |
| `halls_of_rann` | Финал, фаза 3 | 2:30 | Finale: the halls of the sea goddess. Full wordless choir, the main theme slowed down and grand, strings and bells, awe. |
| `morning` | Эпилог | 2:30 | Epilogue morning. Full warm arrangement of the main theme, fiddle, cello, accordion, whistle, 76 bpm, peaceful, hopeful. |

**Слои поверх музыки** (для них промпт стиля не нужен):

| id | Где | Длит. | Промпт |
|---|---|---|---|
| `layer_storm` | Поверх музыки на суше в шторм | 1:00 | Low rumbling storm drums and tremolo low strings, no melody, loopable texture. |
| `layer_hmar` | Поверх музыки в море в ночь Хмари | 1:00 | Eerie detuned glass harmonica swells and whispering choir texture, no melody, loopable. |

## Атмосферы — 11 петель (Sound Effects)

| id | Где | Промпт |
|---|---|---|
| `amb_shore` | Мыс, пляжи | Gentle waves on a rocky northern shore, seagulls far away, light wind, loopable. |
| `amb_sea` | Море | Open sea from a small boat: water lapping on the hull, wind, occasional distant gull, loopable. |
| `amb_village` | Деревня днём | Small fishing village ambience: distant voices, a dog far away, wooden creaks, gulls, sea in background, loopable. |
| `amb_tavern` | Таверна | Cosy tavern crowd murmur, clinking mugs, crackling fireplace, loopable, no music. |
| `amb_moor` | Пустошь, лощина, утёс | Moorland wind through heather and birches, skylark far away, loopable. |
| `amb_night` | Суша ночью | Northern night: soft surf, faint wind, a lone owl occasionally, crickets very faint, loopable. |
| `amb_interior` | Дома, маяк | Quiet room inside a stone house, faint wind outside, soft fireplace crackle, loopable. |
| `amb_cave` | Гроты | Sea cave: dripping water echoes, distant waves, hollow air, loopable. |
| `amb_underwater` | Глубь | Deep underwater ambience, muffled low rumble, slow bubbles, loopable. |
| `amb_rain` | Поверх, когда идёт дождь | Steady rain on grass and stone, loopable. |
| `amb_wind` | Поверх, в шторм | Strong gusting storm wind, loopable. |

## Звуки

### Первая очередь — уже подключены в игре

| id | Когда | Промпт |
|---|---|---|
| `ui_click` | Кнопки меню | Soft wooden click of a UI button, short. |
| `ui_back` | Назад / закрыть окно | Soft muted wooden tap, slightly lower, short. |
| `ui_page` | Страница журнала | Paper page turn of an old leather journal. |
| `ui_coins` | Деньги пришли или ушли | A few old coins clinking in a hand. |
| `ui_levelup` | Новый уровень навыка | Short warm chime of small bells rising, magical but gentle. |
| `ui_achievement` | Достижение | Short bright bell flourish, celebratory. |
| `item_get` | Предмет в рюкзак | Tiny soft pop, pleasant. |
| `pickup` | Находка на земле | Small sparkle chime, short. |
| `hoe_dig` | Мотыга, лопата | Hoe digging into wet soil, one strike. |
| `pick_stone` | Кирка по камню | Pickaxe striking stone, one hit with small debris. |
| `axe_chop` | Топор по дереву | Axe chopping driftwood, one chop. |
| `scythe_swish` | Коса по траве | Scythe swish cutting grass. |
| `splash` | Заброс, подсечка, вода | Medium splash in sea water. |
| `splash_small` | Лейка, мелкие брызги | Small water splash, watering can. |
| `dodge` | Рывок | Quick cloth whoosh and a scuff of boots. |
| `bubbles` | Дыхание под водой | Short burst of air bubbles underwater. |
| `octopus_ink` | Осьминог выпустил чернила | Underwater squirt and murky whoosh. |
| `gull_down` | Чайка-мародёр побеждена | Gull squawk and a flutter of feathers. |
| `eat` | Съел еду | Short bite and chew, cosy. |
| `lamp_light` | Лампа маяка зажглась | Oil lamp igniting with a soft whoomph and flame crackle. |
| `fish_landed` | Рыба поймана | Fish flopping on wet wood, short. |
| `station_bell` | Колокол спасательной станции (крушение) | Urgent brass ship bell ringing three times in the distance. |
| `grave_fill` | Похороны: засыпать могилу | Shovel throwing soil onto a grave, two throws. |

### Вторая очередь — звуки подключу в игре, как только появятся файлы

- **Шаги** — по 3 варианта на поверхность: `step_grass`, `step_sand`, `step_stone`, `step_wood`, `step_snow`,
  `step_water`, `step_mud`, `step_indoor`.
- **Рыбалка:** `fish_cast` (свист лески и всплеск поплавка), `fish_bite` (плеск поплавка), `fish_reel`
  (трещотка катушки, петля 1 с), `line_snap` (обрыв лески).
- **Маяк:**
  - `lens_wind` — заводка механизма, 3 оборота с щелчками;
  - `lighthouse_bell` — колокол маяка;
  - `foghorn` — ревун, долгий низкий гудок;
  - `glass_wipe` — протирка стекла;
  - `lens_set` — установка линзы, стеклянный звон и металл.
- **Погост:**
  - `grave_dig` — копка могилы;
  - `marker_set` — установка деревянного знака;
  - `needle` — игла и нитка, шитьё савана;
  - `candle` — свеча, спичка и огонёк;
  - `funeral_bell` — колокольчик отпевания;
  - `whisper` — неразборчивый шёпот призрака.
- **Море:** `oar` (гребок), `sail_flap` (хлопок паруса), `rigging_creak` (скрип снастей), `hull_hit` (удар
  о камень), `wave_hit` (волна о борт).
- **Глубь:** `bell_descent` (спуск колокола, лязг цепи), `helmet_breath` (дыхание в шлеме, петля), `harpoon`
  (выстрел гарпуна).
- **Животные:** `chicken`, `cow`, `sheep`, `goat`, `pony`, `pig`, `duck`, `cat_meow`, `cat_purr` (петля),
  `gulls` (стая чаек).
- **Погода:** `thunder_near`, `thunder_far`.
- **Бой:** `hit_enemy`, `hit_player`, `enemy_die`, `boss_roar`.
- **Голоса жителей** — неразборчивое бормотание, как в Animal Crossing, 6 тембров по 3 варианта:
  - `voice_low_m`, `voice_mid_m`, `voice_high_m` — мужские, низкий, средний, высокий;
  - `voice_low_f`, `voice_mid_f`, `voice_high_f` — женские, так же.
  - Промпт: «Short unintelligible cute mumble syllables, [low male / …] voice, 0.5 s».
- **Сюжетные акценты:** `sting_discovery` (открытие, короткий аккорд), `sting_ghost` (появление призрака),
  `sting_dread` (тревога), `sting_rann` (голос моря — низкий хор и волна).
