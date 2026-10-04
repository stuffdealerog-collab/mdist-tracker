# Иконка и версия EXE без rcedit

```
npm install resedit pe-library
node patch_template.mjs <шаблон windows_release_x86_64.exe> ../icon.ico ../build/template/windows_release_x86_64_kss.exe
```
Пресет «Windows Desktop» уже использует `build/template/windows_release_x86_64_kss.exe` как свой шаблон. Godot кладёт игру в него, поэтому иконка и версия попадают в итоговый EXE.
