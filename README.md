# Cozy Minigolf (Minigolf Relajante)

Minigolf 3D low-poly para Android (Godot 4.7, Jolt Physics, renderizador Mobile)
con controles inspirados en **Neo Turf Masters**.

## Idiomas

Traducido a 15 idiomas: inglés, español, portugués (Brasil), francés, alemán, italiano, ruso, turco,
indonesio, vietnamita, hindi, árabe, japonés, coreano y chino simplificado.

- Se elige solo según el idioma del móvil (si no está en la lista, inglés). El botón **Idioma** del menú lo cambia a mano.
- El nombre bajo el icono de Android también se traduce (`application/config/name_localized` en `project.godot`).
- **Textos:** todos están en `locale/translations.csv` (una fila por texto, una columna por idioma; se abre con Excel o LibreOffice en UTF-8). En el código se usan con `tr("CLAVE")`.
- Japonés, chino, coreano, hindi y árabe usan las fuentes del sistema. En árabe la interfaz se muestra en espejo.
- Conviene que una persona nativa revise las traducciones antes de publicar.

## Pausa

El botón **II** (arriba a la derecha) pausa la partida: **Continuar** o **Volver al menú**. En Android, el botón "atrás" también pausa (y en el menú sale del juego).

## Modos

- **Duelo contra Kaze**: los turnos se alternan (tiras tú, tira Kaze…). Quien ya ha embocado deja de tirar.
  Cada uno tiene su bola (la tuya roja, la de Kaze amarilla) y **las bolas chocan entre sí** como en el billar:
  - la bola golpeada juega desde donde se pare;
  - si la metes en el hoyo de un golpe, cuenta como embocada para su dueño ("¡dentro de carambola!");
  - si la tiras al agua o fuera, vuelve a su sitio sin penalización.
  Con **SALTAR »** el turno de Kaze va más rápido.
- **Kaze se vuelve más difícil según avanzas** (nivel 1 en el primer hoyo, 12 en el último del segundo mundo;
  se ve al presentar cada hoyo): apunta y mide la fuerza cada vez mejor y, desde el nivel 3, juega con
  picardía: esquiva tu bola si se le cruza y, si la tuya está cerca del hoyo y la suya lejos, va a por ella
  para alejarla ("¡Kaze va a por tu bola!"). Todo esto está en `_cpu_think` y `_attack_plan` de `scripts/main.gd`.
- **Práctica**: solo tú, contra tu récord.

- **Duelo por Wi-Fi**: contra otra persona, cada uno con su móvil en **la misma Wi-Fi**.
  1. Menú → **Duelo por Wi-Fi**. Escribe tu nombre.
  2. Uno pulsa **Crear partida** y elige el mundo; el otro lo verá en la lista (**Unirse a …**). Si no aparece
     (algunas redes bloquean la búsqueda), puede usar **Unirse por IP** con la IP que muestra la sala del anfitrión.
  3. El anfitrión pulsa **Empezar**. Los turnos se alternan; en el turno del otro ves en directo su apuntado,
     su barra y sus bolas. Cada uno gana sus propias estrellas y semillas.
  - Si uno se va, el otro vuelve al menú con un aviso. En línea la pausa no detiene la partida.
  - Para jugar desde el PC contra un móvil, Windows puede pedir permiso en el cortafuegos la primera vez:
    acéptalo para **redes privadas**.
  - Código: `scripts/net.gd` (autoload `Net`: sala, búsqueda y mensajes) y la sección "Duelo por Wi-Fi" de `scripts/main.gd`.
  - Prueba automática en red: `--autotest --net-host` en una copia y `--autotest --net-join=127.0.0.1` en otra.

Cada hoyo da hasta 3 estrellas: embocar al par o mejor, recoger las 3 semillas doradas y hacer birdie o mejor.
Con 8 estrellas se desbloquea el segundo mundo, con 24 el tercero y con 40 el cuarto.

## Golpes especiales

Se desbloquean al reunir estrellas (el menú muestra cuáles tienes) y cada jugador puede usar cada uno
**2 veces por hoyo**. Se eligen antes de tirar con el botón que hay junto a **VISTA** (o la tecla `E`):

- **Curva** (4 estrellas): la bola se curva a izquierda o derecha mientras rueda; la mira se dobla hacia ese lado.
- **Salto** (10 estrellas): mientras rueda, pulsa **¡SALTA!** y da un bote que pasa por encima de vallas, huecos y espíritus.
- **Freno** (18 estrellas): mientras rueda, pulsa **¡FRENA!** y se para casi en el acto. Imprescindible en el hielo.

Al desbloquear un golpe o un mundo sale un aviso explicándolo. Kaze no los usa.

## Mundos

1. **Colinas de la Brisa**: pradera de verano, molino, arroyo, setas saltarinas, terrazas y puente.
2. **Bosque de los Espíritus** (se desbloquea con 8 estrellas): bosque al atardecer con luciérnagas
   y setas que brillan. Novedades: tronco hueco, espíritus del bosque que flotan de lado a lado y
   rebotan la bola, portales mágicos, escalera de raíces con troncos caídos y un árbol gigante.
   Tiene su propia música.
3. **Islas entre las Nubes** (24 estrellas): islas flotantes sobre un mar de nubes. Si la bola se sale
   por un borde sin valla, cae a las nubes. Novedades: puentes sin barandilla, trampolín de nube,
   rachas de viento que empujan al vacío, **flechas de impulso** para subir rampas y un archipiélago.
4. **Cumbre Nevada** (40 estrellas): montañas nevadas y copos cayendo. Novedades: **hielo** (la bola
   apenas frena), **nieve blanda** (frena mucho), tobogán de hielo cuesta abajo, ventisca y agua helada.

`Jugar (todo desbloqueado).bat` abre el juego con todos los mundos disponibles, para probar.

## Juguetes del recorrido

Rampas de salto, espíritus del bosque, portales, troncos huecos, setas saltarinas (lanzan la bola por encima de las vallas), setas rebotadoras,
tuberías que llevan a otra parte del hoyo, brazos giratorios, molino con aspas, viento con ráfagas,
agua, arena, terrazas y desniveles, flechas de impulso, hielo y nieve blanda.

## Cómo se juega

1. **Apuntar**: arrastra el dedo a los lados (o usa `<` `>`). Las flechas del
   suelo indican hacia dónde cae la pendiente: cuanto más rojas y rápidas, más inclinada.
2. **GOLPE** (1.er toque): la barra de fuerza empieza a subir y bajar.
3. **FUERZA** (2.º toque): fija la fuerza, que queda marcada con una línea roja. La marca sigue subiendo y bajando, más despacio.
   - Cerca del hoyo (4 m o menos, con el hoyo a la vista) aparece la **línea amarilla**: la fuerza justa para llegar si fuera en llano.
   - Por encima de la línea blanca (100 %) está la **zona roja**: pega más fuerte, pero la bola sale desviada.
4. **¡YA!** (3.er toque): pulsa cuando la marca pase por la línea roja. En la franja blanca: ¡PERFECTO!; en la azul: BIEN.
   Si pulsas con la marca por encima de la línea, la bola se va a la izquierda; por debajo, a la derecha. Nunca golpea sola: si fallas la pasada, espera a la siguiente.
5. Mientras rueda, **desliza** a un lado una vez para darle efecto.

- **VISTA**: cambia entre la cámara detrás de la bola y la vista general.
- Agua o fuera del recorrido: +1 golpe y repites desde donde estabas. El máximo son 7 golpes; si no embocas, se anotan 8.
- En PC: flechas para apuntar, `Espacio` para golpear (y para saltar o frenar), `V` para la vista,
  y `E` para el golpe especial.

## iPhone / iPad (TestFlight, sin Mac)

Igual que en *Carreras de Canicas*: el juego se compila para iOS en un Mac de GitHub (GitHub Actions)
y se sube a **TestFlight**; desde ahí se instala en el iPhone. El workflow está en `.github/workflows/ios.yml`.

Configuración (solo la primera vez). La cuenta de Apple Developer, la clave de API y el Team ID son los mismos de
las canicas; solo hay que crear la app nueva y copiar los secretos al repositorio de este juego:

1. **Crear la app** en [App Store Connect](https://appstoreconnect.apple.com) → *Apps* → **+** → *Nueva app*:
   - Plataforma iOS, nombre "Minigolf Relajante" (o "Cozy Minigolf") e idioma principal español.
   - ID de paquete (*Bundle ID*): `com.hernandiaz.cozyminigolf`. Si no aparece en la lista, créalo antes en
     developer.apple.com → *Identifiers* → **+** → *App IDs*.
   - SKU: cualquiera, por ejemplo `cozy-minigolf`.
2. **Secretos en GitHub:** en el repositorio de este juego, *Settings* → *Secrets and variables* → *Actions* →
   *New repository secret*. Los mismos cuatro que en las canicas (GitHub no deja copiarlos de un repositorio a otro):

   | Nombre | Valor |
   |---|---|
   | `APPLE_TEAM_ID` | el Team ID |
   | `ASC_KEY_ID` | el Key ID de la clave de API |
   | `ASC_ISSUER_ID` | el Issuer ID |
   | `ASC_KEY_P8` | el contenido completo del `.p8` (incluidas las líneas `BEGIN`/`END`) |

Para compilar una versión: GitHub → *Actions* → **iOS (TestFlight)** → *Run workflow*. Tarda unos 20 minutos.
Cuando termina, aparece en App Store Connect → *TestFlight*; añádete como probador interno e instálala con la app
**TestFlight** del iPhone.

Notas:
- **Minutos de GitHub:** en un repositorio privado, las máquinas Mac gastan minutos del plan x10.
- **Duelo por Wi-Fi en iPhone:** la búsqueda automática de partidas necesita el permiso *multicast* de Apple (el mismo
  que se pidió para las canicas, pero es por app). Mientras tanto funciona **Unirse por IP**. iOS pide permiso de
  "red local" la primera vez.
- **Botón Salir:** en iOS no aparece, porque las apps no pueden cerrarse solas.
- **Icono:** `icons/icon_1024.png` (sin transparencias). Se genera con
  `godot --headless --path . -s res://tools/render_icons.gd` junto con los de Android.
- **Ajustes de iOS:** preset "iOS" de `export_presets.cfg`. El Team ID no se guarda en el repositorio: lo pone el workflow.

## Archivos

| Archivo | Qué hace |
|---|---|
| `Jugar.bat` | Ejecuta el juego en el PC |
| `Abrir editor.bat` | Abre el proyecto en Godot |
| `Instalar en Android.bat` | Compila el APK y lo instala en el móvil conectado por USB |

## Estructura

- `scripts/holes.gd`: **los hoyos** del recorrido "Colinas de la Brisa". Cada uno es un mapa de casillas de 1 m
  (`.` césped, `T` salida, `H` hoyo, `s` arena, `r` rampa, `~` agua) con un mapa opcional de **niveles**
  (un dígito por casilla, 0,25 m cada nivel; entre niveles distintos hay un desnivel por el que la bola cae),
  una función de alturas suave, obstáculos (`windmill`, `stone`, `fence`, `wind`) y una ruta de puntos.
- `scripts/hole_builder.gd`: genera el suelo, los bordes, los desniveles, el agua, los obstáculos y el decorado (árboles, hierba, flores).
- `scripts/world_decor.gd`: cielo, bruma, prado, colinas lejanas y nubes.
- `scripts/looks.gd` y `shaders/`: estilo visual (iluminación de dibujo animado suave, hierba con viento, agua).
- `scripts/wind_zone.gd`: zonas de viento con ráfagas.
- `scripts/ball.gd`: física de la bola (rodadura, arena, efecto, parada).
- `scripts/main.gd`: flujo de partida, golpe en tres toques y puntuación.
- `scripts/hud.gd` y `scripts/meter.gd`: interfaz táctil y barra de potencia.
- `scripts/slope_grid.gd`: rejilla animada de pendientes.
- `scripts/cam_rig.gd`: cámaras.
- `scripts/sfx.gd`: sonidos sintetizados, sin archivos de audio.

## Prueba automática

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest
```
Juega los hoyos solo y muestra en la consola los golpes de cada uno.
Opciones: `--world=N` (0-3) y `--hole=N` para empezar en otro sitio, `--hotseat` para 2 jugadores y
`--try-specials` para que use golpes especiales al azar.
