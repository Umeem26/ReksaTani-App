# Data attribution

The scripts in this folder read public datasets that are **not** included in this repository. Download them from the sources below; each is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), which requires attribution.

## Oil palm fruit bunches (`prepare_sawit_public.py`, `train_sawit.py`)

Suharjito & Junior, "Annotated Video Dataset of Oil Palm Fruit Bunch Piles for Ripeness Grading", Science Data Bank, 2023.
DOI: [10.57760/sciencedb.j00001.00713](https://doi.org/10.57760/sciencedb.j00001.00713). License: CC BY 4.0.
Related paper: Junior et al., *Scientific Data* 10, 72 (2023).

## Coffee beans (`coffee_cv.py`)

CBD Coffee Beans Dataset, Mendeley Data.
DOI: [10.17632/52877z55vr.1](https://doi.org/10.17632/52877z55vr.1). License: CC BY 4.0.

## Changes

Neither dataset is redistributed here. The scripts crop, resize, and relabel images locally; the mapping from dataset classes to grades A/B/C is a draft (rubric `v0.1-draf`) and has not been reviewed by a domain expert.
