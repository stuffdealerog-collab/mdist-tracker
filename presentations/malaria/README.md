# Malaria: групповая презентация (Group Oral Presentation)

Спикеры: Azamov Javohir (вступление + вывод), Asatullayev Muhammadrizo (история),
Bakiyev Ramazan (статистика), Abduraimov Akmalbek (вакцина, профилактика, лечение).

## Готовые файлы (`output/`)

| Файл | Что это |
|---|---|
| `Malaria_Group_Presentation.pptx` | 16 слайдов, переходы Morph, анимации стартуют сами: один клик = следующий слайд. Текст речи в заметках к каждому слайду, секции по спикерам |
| `Malaria_Group_Presentation_backup.pdf` | PDF-копия на случай, если на компьютере нет PowerPoint |
| `Malaria_Prep_Sheet.pdf` | Prep pack: вся речь как одна история, тайминг, передачи слова, текст каждого спикера, страница памяти (крючки, карточка для сцены, самопроверка), план на 4 дня, вопросы, источники каждой цифры |
| `audio/00_Full_run-through_all_speakers.mp3` | Вся речь в 4 голоса, мягкий щелчок = смена слайда |
| `audio/0N_<Имя>_1_my_part.mp3` | Только твоя часть, перед каждым входом звучит последняя фраза предыдущего спикера |
| `audio/0N_<Имя>_2_shadowing.mp3` | Фраза, потом пауза такой же длины: повторяй вслух |

## Пересборка

```bash
npm install                        # pptxgenjs, sharp, react-icons, jszip
python3 src/gen_images.py          # фото через GPT-image (OpenRouter), нужен OPENROUTER_API_KEY
node src/build_deck.js             # презентация
python3 src/tts_blocks.py && python3 src/make_audio.py   # аудио из build/audio_raw
node src/build_prep.js             # prep sheet
```

Весь текст речи и список источников лежат в `src/content.json`, данные для prep sheet в `src/prep_data.json`.
Фото сгенерированы GPT-image (`openai/gpt-5.4-image-2`), портреты учёных взяты из Wellcome Collection (public domain), логотип с mdist.uz.
