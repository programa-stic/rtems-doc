# README

[RTEMS](https://www.rtems.org/) es un sistema operativo de tiempo real de código abierto con orígenes en los finales de los años 80. Es utilizado en áreas tan diversas como la aeroespacial, médica y redes. También, brinda soporte para una extensa gama de arquitectura de procesadores que incluyen ARM, Intel, MIPS, PowerPC y varios más. Entre sus usuarios están NASA, ESA, MITRE, JPL, etc.

Este repositorio reune notas que van desde la instalación del entorno de desarrollo pasando por la instalación en una RaspberryPi y el relevamiento del código fuente hasta aspectos básicos de seguridad. Esta notas están compiladas en forma de un documento que se puede descargar desde el siguiente [link](doc/build/latex/RTEMS.pdf).

Además, hay disponible varios ejemplos/demos para probar ciertos aspectos de seguridad. Para más información, leer [README.md](example/demos/README.md).

En la siguiente [presentación](slides/rtems.pdf) destaca los aspectos más relevantes del proyecto.

## Documentación

La documentación se puede descargar desde el siguiente [link](doc/build/latex/RTEMS.pdf). También puede ser generada desde los fuentes tal como se indica a continuación.

### Generación

Para este proyecto se utiliza el sistema de documentación *[Sphinx](http://sphinx-doc.org)*.

```bash
sudo apt-get install python-sphinx
```

Para poder generar la documentación hay que realizar lo siguiente:

```bash
cd doc
make latexpdf
```

Puede ser necesario instalar paquetes de `texlive`:

```bash
sudo apt-get install texlive-latex-extra
sudo apt-get install texlive-fonts-recommended
```

Esto genera un documento pdf (`RTEMS.pdf`) que se encuentra en la carpeta `doc/_build/latex/`.

### Extensión

Los *fuentes* de la documentación se encuentran en la carpeta `doc/source` y están escritos en formato **ReStructureText**. El índice principal está en `doc/index.rst`.

## Licencia

Este proyecto se encuentra bajo la licencia `BSD 2-Clause License`. Para más información, leer [LICENSE](./LICENSE.md).
