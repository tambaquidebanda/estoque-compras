#!/bin/bash
# Dois cliques: sobe o ambiente de teste da reuniao (porta 8092, copia propria em teste/dados_reuniao)
# e abre a tela com os celulares lado a lado. Nada aqui toca o sistema de verdade.
cd "$(dirname "$0")/.."
if curl -s -o /dev/null http://localhost:8092/tv; then
  open "http://localhost:8092/tv"
  exit 0
fi
(sleep 2; open "http://localhost:8092/tv") &
echo "Deixe esta janela aberta durante a reuniao. Para desligar: feche a janela."
DADOS_TESTE=dados_reuniao PORTA=8092 python3 teste/servidor.py
