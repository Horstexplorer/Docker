#!bin/sh
conda deactivate
conda create -n env python=3.13 ipykernel
conda activate env
python -m ipykernel install --name env --user
conda deactivate