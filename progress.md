Original prompt: vamos usar esse tÃ³pico para trabalhar na movimentaÃ§Ã£o do player. O jogo serÃ¡ estruturado como um survival horror top-down entÃ£o deve ser punitivo por mal gerenciamento de stamina e posicionamento

- Refatorado `scripts/player.gd` para movimento com estados explÃ­citos (`normal`, `sprinting`, `exhausted`), aceleraÃ§Ã£o e frenagem.
- Velocidades passaram a usar valores inteiros para combinar melhor com pixel snap e reduzir jitter visual.
- Sprint agora drena stamina de forma agressiva; ao zerar, entra em exaustÃ£o com cooldown e velocidade reduzida.
- `scenes/player.tscn` agora liga smoothing leve na cÃ¢mera para manter amortecimento controlado.
- `scripts/world.gd` atualiza a UI de stamina com estados distintos: `STA`, `RUN`, `REC`, `CD`.
- Ajustado o feel para mais inÃ©rcia reduzindo aceleraÃ§Ã£o/frenagem e adicionando resposta mais lenta em reversÃµes bruscas.
- Removido o `global_position.round()` do loop normal de movimento; o snap duro ficou restrito Ã  transiÃ§Ã£o de salas para evitar jitter visual.
- Desligado `snap_2d_transforms_to_pixel` no projeto e o smoothing normal da cÃ¢mera para atacar a origem estrutural do jitter visual.
- A velocidade de corrida foi aumentada em 150%, elevando `SPRINT_SPEED` de `120` para `300`.

TODO:
- Validar em runtime se a combinaÃ§Ã£o sem transform snap e sem smoothing elimina o jitter em diagonal e em linha reta.
- Ajustar os nÃºmeros de aceleraÃ§Ã£o, sprint e exaustÃ£o conforme playtest.
- Se ainda houver tremor, investigar um pivot visual separado do corpo fÃ­sico ou callback explÃ­cito de cÃ¢mera em fÃ­sica.
- Implementado evento hostil diurno: som `Crickets.mp3`, aviso de 10s, inimigo placeholder em circuito externo e expulsao no contato.
- Falta validar em runtime o circuito do inimigo e ajustar a distancia dos waypoints para a tensao desejada.

- Reestruturado `scripts/world.gd` para transformar a fazenda em um loop de sobrevivÃªncia mais completo.
- A bolsa de sementes virou ponto de abastecimento contÃ­nuo: primeira coleta gratuita e compras posteriores por moedas.
- Adicionados fome, sede e vida com desgaste passivo, recuperaÃ§Ã£o limitada e colapso com penalidade de moedas.
- O poÃ§o agora mata a sede e, com o balde equipado, tambÃ©m recarrega as cargas de Ã¡gua.
- A colheita pode ser comida com `Q` para recuperar fome/vida; o balde equipado tambÃ©m pode ser usado com `Q` para beber Ã¡gua armazenada.
- Adicionado loop de madeira via pontos de coleta com machado e respawn simples.
- Implementados gerador e refletores em runtime; a lenha abastece o gerador e a luz protege a fazenda Ã  noite.
- O evento hostil virou uma primeira versÃ£o do Goatman noturno, com aviso, perseguiÃ§Ã£o e recuo quando entra na Ã¡rea iluminada.
- `scripts/player.gd` agora aceita modificadores externos de velocidade e regen de stamina para reagir Ã  fome/sede/vida.
- `scripts/farm_enemy.gd` ganhou comportamento de recuo Ã  luz e sinal dedicado para esse estado.

TODO:
- Validar em runtime se os nÃ³s criados dinamicamente em `world.gd` aparecem nas posiÃ§Ãµes corretas e nÃ£o interferem com colisÃµes existentes.
- Balancear drenagem de fome/sede, custo das sementes, valor de venda da colheita e duraÃ§Ã£o do combustÃ­vel do gerador.
- Verificar se a hotbar de 5 slots comporta confortavelmente balde, machado, sementes, colheita e lenha sem gerar fricÃ§Ã£o ruim.
- Validar em runtime o comportamento do Goatman quando o gerador liga/desliga durante a perseguiÃ§Ã£o.
- Considerar separar `world.gd` em controladores menores se essa base for mantida no prÃ³ximo passo.
