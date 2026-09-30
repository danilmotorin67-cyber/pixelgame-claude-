# Звуки второй очереди — промпты для ElevenLabs

Раздел Sound Effects. Промпты на английском — так модель понимает точнее. Скачивать в WAV, называть файл ровно по
id (как в таблицах). Тишину в начале и в конце, громкость и петли я доделываю сам, так что длительность можно
ставить с небольшим запасом.

## Как генерировать

- **Duration** — ставить вручную, как в столбце «Сек». Авто-длительность часто даёт лишний хвост.
- **Prompt influence** — 0.6–0.7 для всего, кроме голосов и акцентов (там 0.4–0.5, чтобы было живее).
- **Loop** — включать только там, где написано «петля».
- ElevenLabs даёт 4 варианта за раз. Где нужно 3 варианта — берите три лучших из одной генерации и называйте
  `_1`, `_2`, `_3` (например `step_grass_1.wav`). Игра сама выбирает случайный, чтобы звук не приедался.
- В каждый промпт уже вписан хвост **dry, close, no music, no background** — он отрезает музыку и лишний фон.
  Если звук всё равно выходит с музыкой или эхом — добавьте в конец **isolated sound effect**.

## Шаги — по 3 варианта на поверхность

Один шаг в файле, не походка. Если выходит несколько шагов — добавьте **only one step**.

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `step_grass` | `step_grass_1..3` | 0.5 | Single footstep of a leather boot on short wet grass, soft rustle and dull thud, one step, dry, close, no music, no background |
| `step_sand` | `step_sand_1..3` | 0.5 | Single footstep of a leather boot on damp beach sand, soft crunchy scuff, one step, dry, close, no music, no background |
| `step_stone` | `step_stone_1..3` | 0.5 | Single footstep of a heavy leather boot on bare rock, hard tap with a little grit, one step, dry, close, no music, no background |
| `step_wood` | `step_wood_1..3` | 0.5 | Single footstep of a leather boot on old wooden planks of a pier, hollow knock with a faint creak, one step, dry, close, no music, no background |
| `step_snow` | `step_snow_1..3` | 0.5 | Single footstep of a boot in fresh cold snow, soft squeaky crunch, one step, dry, close, no music, no background |
| `step_water` | `step_water_1..3` | 0.6 | Single footstep of a boot in ankle-deep sea water, small slosh and splash, one step, dry, close, no music, no background |
| `step_mud` | `step_mud_1..3` | 0.6 | Single footstep of a boot in thick wet mud, sticky squelch as the foot lifts, one step, dry, close, no music, no background |
| `step_indoor` | `step_indoor_1..3` | 0.5 | Single footstep of a soft leather boot on a wooden floor inside a small cottage, muffled knock, one step, dry, close, no music, no background |

## Рыбалка

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `fish_cast` | `fish_cast` | 1.2 | Fishing rod cast: quick whoosh of the line through the air, reel clicking, then a small plop of a float landing in sea water, dry, close, no music |
| `fish_bite` | `fish_bite` | 0.6 | Fishing float suddenly pulled under water, short sharp bloop and small splash, dry, close, no music, no background |
| `fish_reel` | `fish_reel` | 1.0, петля | Old fishing reel ratchet clicking steadily while winding in the line, even tempo, continuous, seamless loop, dry, close, no music |
| `line_snap` | `line_snap` | 0.6 | Taut fishing line snapping with a sharp twang, then slack line whipping, dry, close, no music, no background |

## Маяк

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `lens_wind` | `lens_wind` | 2.5 | Winding a heavy clockwork mechanism of a lighthouse with a crank: three slow turns, each with a ratchet clack, brass gears and iron, dry, close, no music |
| `lighthouse_bell` | `lighthouse_bell` | 4 | One strike of a large bronze lighthouse bell, deep clear tone with a long natural ring out, outdoors by the sea, no music |
| `foghorn` | `foghorn` | 5 | Old lighthouse foghorn: one long deep low blast, mournful, fading over the sea, no music |
| `glass_wipe` | `glass_wipe` | 1.2 | Cloth rag wiping a large glass lens, two quick squeaky strokes, dry, close, no music, no background |
| `lens_set` | `lens_set` | 1.2 | Heavy glass lens set into a brass frame: soft glass chime, then a metal clamp clicking shut, dry, close, no music |

## Погост

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `grave_dig` | `grave_dig_1..3` | 1 | Iron spade digging into heavy wet earth with small stones, one scoop thrown aside, dry, close, no music, no background |
| `marker_set` | `marker_set` | 1.2 | Wooden grave marker pushed into soil and knocked down with two mallet taps, dry, close, no music, no background |
| `needle` | `needle` | 1.5 | Needle and thick thread sewing coarse linen by hand, two slow pulls of the thread through cloth, quiet, dry, close, no music |
| `candle` | `candle` | 1.5 | Match struck on a box, flares up, candle wick catches with a soft flutter of flame, quiet, dry, close, no music |
| `funeral_bell` | `funeral_bell` | 3 | Small hand bell rung slowly twice at a funeral, clear thin tone ringing out, solemn, no music |
| `whisper` | `whisper_1..3` | 2 | Unintelligible ghostly whisper, breathy and cold, a few words that cannot be made out, slightly reverberant, eerie, no music |

## Море

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `oar` | `oar_1..3` | 1 | One stroke of a wooden oar in the sea: oar creaking in the oarlock, blade dipping and pulling water, dry, close, no music |
| `sail_flap` | `sail_flap` | 1 | Canvas sail catching the wind with one loud flap and snap, ropes tightening, no music |
| `rigging_creak` | `rigging_creak_1..3` | 1.5 | Wooden mast and hemp rigging of a small sailboat creaking under strain, slow groan, dry, close, no music |
| `hull_hit` | `hull_hit` | 1.2 | Wooden boat hull hitting a rock: heavy thud, wood cracking, water splashing, no music |
| `wave_hit` | `wave_hit_1..3` | 1.2 | Sea wave slapping against the side of a wooden boat, splash and spray, close, no music |

## Глубь

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `bell_descent` | `bell_descent` | 4 | Heavy iron diving bell lowered into the sea: chain clanking and rattling on a winch, then muffled water closing over, no music |
| `helmet_breath` | `helmet_breath` | 3, петля | Diver breathing inside an old brass diving helmet: slow inhale and exhale through a hose, hollow and metallic, air hiss, seamless loop, no music |
| `harpoon` | `harpoon` | 0.8 | Underwater harpoon gun firing: sharp spring release and a whoosh through water, muffled, no music |

## Животные

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `chicken` | `chicken_1..3` | 1 | Farm hen clucking softly a few times, close, dry, no music, no background |
| `cow` | `cow_1..3` | 1.5 | Cow giving one short low moo, close, dry, no music, no background |
| `sheep` | `sheep_1..3` | 1 | Sheep giving one short bleat, close, dry, no music, no background |
| `goat` | `goat_1..3` | 1 | Goat giving one short nasal bleat, close, dry, no music, no background |
| `pony` | `pony_1..3` | 1.5 | Small pony giving a short snort and a soft whinny, close, dry, no music, no background |
| `pig` | `pig_1..3` | 1 | Pig giving a few short grunts, close, dry, no music, no background |
| `duck` | `duck_1..3` | 1 | Duck giving a few short quacks, close, dry, no music, no background |
| `cat_meow` | `cat_meow_1..3` | 1 | House cat giving one short friendly meow, close, dry, no music, no background |
| `cat_purr` | `cat_purr` | 3, петля | House cat purring steadily and contentedly, continuous, seamless loop, close, dry, no music |
| `gulls` | `gulls` | 3 | Small flock of seagulls calling overhead by the sea, a few cries, no music |

## Погода

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `thunder_near` | `thunder_near_1..3` | 4 | Close lightning strike: sharp crack of thunder followed by a heavy rumble over the sea, no music, no rain |
| `thunder_far` | `thunder_far_1..3` | 5 | Distant rolling thunder over the sea, long low rumble, no music, no rain |

## Бой

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `hit_enemy` | `hit_enemy_1..3` | 0.5 | Punchy hit of a blade or club on a creature, wet thwack, short, game sound effect, dry, no music |
| `hit_player` | `hit_player_1..3` | 0.5 | Player taking a hit: dull thump on a thick wool coat and a short grunt of pain, game sound effect, dry, no music |
| `enemy_die` | `enemy_die_1..3` | 1 | Sea creature defeated: short gurgling screech that fades, with a wet splat, game sound effect, no music |
| `boss_roar` | `boss_roar` | 3 | Huge ancient sea monster roaring underwater, deep, rumbling and distorted, with bubbles, frightening, no music |

## Голоса жителей

Неразборчивое бормотание, как в Animal Crossing: игра проигрывает слог-другой на каждую реплику. Prompt influence
0.4–0.5. Если в ответ выходит речь на английском — добавьте **no real words, gibberish**.

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `voice_low_m` | `voice_low_m_1..3` | 0.6 | Short unintelligible cute mumble syllables, low deep male voice, gibberish, no real words, like a cartoon villager, dry, close, no music |
| `voice_mid_m` | `voice_mid_m_1..3` | 0.6 | Short unintelligible cute mumble syllables, medium male voice, gibberish, no real words, like a cartoon villager, dry, close, no music |
| `voice_high_m` | `voice_high_m_1..3` | 0.6 | Short unintelligible cute mumble syllables, high young male voice, gibberish, no real words, like a cartoon villager, dry, close, no music |
| `voice_low_f` | `voice_low_f_1..3` | 0.6 | Short unintelligible cute mumble syllables, low warm female voice, gibberish, no real words, like a cartoon villager, dry, close, no music |
| `voice_mid_f` | `voice_mid_f_1..3` | 0.6 | Short unintelligible cute mumble syllables, medium female voice, gibberish, no real words, like a cartoon villager, dry, close, no music |
| `voice_high_f` | `voice_high_f_1..3` | 0.6 | Short unintelligible cute mumble syllables, high girlish female voice, gibberish, no real words, like a cartoon villager, dry, close, no music |

## Сюжетные акценты

Короткие музыкальные удары поверх сцены. Здесь музыка как раз нужна, поэтому **no music** в промптах нет.
Prompt influence 0.5.

| id | Файлы | Сек | Промпт |
|---|---|---|---|
| `sting_discovery` | `sting_discovery` | 3 | Short musical sting of discovery: a soft rising chord on celesta and strings with a gentle shimmer, mysterious and warm, Nordic folk feel |
| `sting_ghost` | `sting_ghost` | 3 | Short eerie musical sting for a ghost appearing: cold glassy shimmer, bowed cymbal, a faint breathy choir swell, then silence |
| `sting_dread` | `sting_dread` | 3 | Short tense musical sting of dread: low cello cluster and a deep drum hit, a dissonant swell that cuts off |
| `sting_rann` | `sting_rann` | 6 | The voice of the sea goddess: a deep low wordless female choir rising out of a slow heavy ocean wave, ancient and vast, reverberant |
