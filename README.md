# README

## Documentación

Para este proyecto se utiliza el sistema de documentación *[Sphinx](http://sphinx-doc.org)*.

```bash
sudo apt-get install python-sphinx
```

Para poder generar la documentación hay que realizar lo siguiente:

```bash
cd doc
make latexpdf
```

Pudiendo ser necesario instalar los paquetes de texlive:

```bash
sudo apt-get install texlive-latex-extra
sudo apt-get install texlive-fonts-recommended
```

Esto genera un documento pdf (`RTEMS.pdf`) que se encuentra en la carpeta `doc/_build/latex/`.

### Extendiendo la documentación

Los *fuentes* de la documentación se encuentran en la carpeta `doc/source` y están escritos en formato **ReStructureText**. El índice principal está en `doc/index.html`.
