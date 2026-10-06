# Ubatuba a Dois

Roteiro interativo da viagem para Ubatuba (10–12/10/2026).

## Publicação no GitHub Pages

1. Crie um repositório chamado `ubatuba-a-dois`.
2. Envie os arquivos deste diretório para a branch `main`.
3. No GitHub: **Settings → Pages**.
4. Em **Build and deployment**, escolha **Deploy from a branch**.
5. Selecione `main` e `/ (root)`.
6. Salve. A página ficará em algo como:
   `https://SEU-USUARIO.github.io/ubatuba-a-dois/`

## Login Google + sincronização

O front-end já contém a integração com Supabase Auth + Google OAuth e sincronização
do estado da viagem. Para ativar:

1. Crie um projeto no Supabase.
2. Execute `supabase_setup.sql` no **SQL Editor**.
3. Em **Authentication → Providers → Google**, habilite o Google.
4. No Google Cloud, crie o OAuth Client e use a callback do Supabase.
5. No Supabase, em **Authentication → URL Configuration**:
   - Site URL: URL do GitHub Pages
   - Redirect URL: a mesma URL do GitHub Pages
6. Abra o site publicado → Checklist → **Configurar**.
7. Informe:
   - Supabase Project URL
   - Supabase anon/public key
8. Depois use **Entrar com Google**.

## Privacidade

Este repositório não deve conter RG, datas de nascimento, placa do veículo,
código de confirmação da reserva ou telefone privado.

## Arquivos

- `index.html`: site completo
- `supabase_setup.sql`: banco, RLS e funções de compartilhamento
- `.nojekyll`: compatibilidade com GitHub Pages
