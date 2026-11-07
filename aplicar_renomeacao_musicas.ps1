# reorganizar_musicas.ps1
# Renomeia TODOS os MP4 da pasta para "NUMERO - ARTISTA - MUSICA.mp4", em ordem alfabetica
# (artista, depois musica), unificando variacoes de nome de artista.
# NADA e excluido: arquivos fora do padrao ou ambiguos tambem entram na sequencia.
#
# Simulacao (NAO renomeia nada, so gera o CSV de conferencia):
#   powershell -ExecutionPolicy Bypass -File .\reorganizar_musicas.ps1
# Aplicar de verdade:
#   powershell -ExecutionPolicy Bypass -File .\reorganizar_musicas.ps1 -Executar

param(
    [string]$Pasta = "D:\musicas",
    [switch]$Executar
)

# Versao 'aplicar': executa a renomeacao sem precisar de parametro
$Executar = $true

$ErrorActionPreference = "Stop"

function Remove-Acentos([string]$s) {
    $d = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString()
}

# Chave de comparacao do artista: sem acento, sem "(The)", sem artigo inicial (O, Os, A, As, The)
function Get-ChaveArtista([string]$s) {
    $t = (Remove-Acentos $s).ToLowerInvariant()
    $t = $t -replace '\(the\)', ''
    $t = $t -replace '[^a-z0-9 ]', ' '
    $t = ($t -replace '\s+', ' ').Trim()
    return ($t -replace '^(os|o|as|a|the) ', '')
}

# Chave de comparacao da musica: sem acento, sem pontuacao (artigos mantidos)
function Get-ChaveMusica([string]$s) {
    $t = (Remove-Acentos $s).ToLowerInvariant()
    $t = $t -replace '[^a-z0-9 ]', ' '
    return (($t -replace '\s+', ' ').Trim())
}

# Nome canonico por artista (chave -> nome final)
$canon = @{
    'alceu valenca'        = 'Alceu Valença'
    'barao vermelho'       = 'Barão Vermelho'
    'biquini cavadao'      = 'Biquini Cavadão'
    'capital inicial'      = 'Capital Inicial'
    'cassia eller'         = 'Cássia Eller'
    'claudinho e buchecha' = 'Claudinho e Buchecha'
    'legiao urbana'        = 'Legião Urbana'
    'legiao urbano'        = 'Legião Urbana'
    'lobao'                = 'Lobão'
    'lulu santos'          = 'Lulu Santos'
    'marilia mendonca'     = 'Marília Mendonça'
    'nenhum de nos'        = 'Nenhum de Nós'
    'paralamas do sucesso' = 'Os Paralamas do Sucesso'
    'rappa'                = 'O Rappa'
    'tim maia'             = 'Tim Maia'
    'titas'                = 'Titãs'
    'victor e leo'         = 'Victor e Leo'
    'wanessa camargo'      = 'Wanessa Camargo'
    'ze ramalho'           = 'Zé Ramalho'
    'ze neto e cristiano'  = 'Zé Neto e Cristiano'
    'ze neto e critiano'  = 'Zé Neto e Cristiano'
    'ze neto e crstiano'  = 'Zé Neto e Cristiano'
    'beatles'              = 'Beatles'
}

# 1) Ler todos os MP4 e separar NUMERO / ARTISTA / MUSICA
$regexEstrito = '^(\d+) - (.+?) - (.+)\.mp4$'   # "N - Artista - Musica.mp4"
$regexFlex    = '^(\d+) - (.+?)\s*-\s*(.+)\.mp4$'  # aceita hifen colado: "Artista- Musica"
$arquivos = @(Get-ChildItem -LiteralPath $Pasta -File | Where-Object { $_.Extension -ieq '.mp4' })
$itens = @()
$foraDoPadrao = @()
$ambiguos = @()

foreach ($f in $arquivos) {
    if ($f.Name -match $regexEstrito -or $f.Name -match $regexFlex) {
        $numAntigo  = [int]$Matches[1]
        $artistaRaw = ($Matches[2] -replace '\s+', ' ').Trim()
        $musica     = ($Matches[3] -replace '\s+', ' ').Trim()
        # Mais de um " - " depois do artista: o script usa o primeiro trecho como artista.
        # O arquivo entra na sequencia normalmente, mas vai para a lista de revisao.
        if ($musica -match ' - ') { $ambiguos += $f.Name }
    } else {
        # Nome fora do padrao: entra na sequencia com o nome (sem numero) como artista e musica vazia
        $foraDoPadrao += $f.Name
        $numAntigo  = 0
        $semExt     = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $semNum     = $semExt -replace '^\d+\s*-\s*', ''
        $artistaRaw = ($semNum -replace '\s+', ' ').Trim()
        $musica     = ""
    }
    $chave = Get-ChaveArtista $artistaRaw
    if ($canon.ContainsKey($chave)) { $artista = $canon[$chave] } else { $artista = $artistaRaw }
    $itens += [pscustomobject]@{
        Arquivo   = $f
        NumAntigo = $numAntigo
        Artista   = $artista
        Musica    = $musica
        ChaveA    = Get-ChaveArtista $artista
        ChaveM    = Get-ChaveMusica $musica
    }
}

# 2) Ordenar: artista, depois musica, depois numero antigo
$ordenados = @($itens | Sort-Object ChaveA, ChaveM, NumAntigo)

# 3) Novo numero sequencial e novo nome (todos os arquivos recebem numero)
$largura = [Math]::Max(4, ([string]$ordenados.Count).Length)
$i = 0
foreach ($it in $ordenados) {
    $i++
    $num = $i.ToString("D$largura")
    if ($it.Musica -ne "") { $meio = "$($it.Artista) - $($it.Musica)" } else { $meio = $it.Artista }
    $nome = ("$num - " + $meio + ".mp4") -replace '[\\/:*?"<>|]', ''
    $it | Add-Member -NotePropertyName NumNovo  -NotePropertyValue $i
    $it | Add-Member -NotePropertyName NovoNome -NotePropertyValue $nome
}

# 4) Relatorio
Write-Host ""
Write-Host "MP4 encontrados:        $($arquivos.Count)"
Write-Host "Serao numerados (todos): $($ordenados.Count)"
Write-Host ""
Write-Host "Fora do padrao 'N - Artista - Musica' (entraram na sequencia com o nome completo como artista): $($foraDoPadrao.Count)"
foreach ($n in $foraDoPadrao) { Write-Host "   - $n" }
Write-Host ""
Write-Host "Ambiguos (mais de um ' - ' depois do artista; o primeiro trecho virou artista). REVISAR a mao: $($ambiguos.Count)"
foreach ($n in $ambiguos) { Write-Host "   - $n" }
Write-Host ""

$dups = @($ordenados | Group-Object { $_.ChaveA + '|' + $_.ChaveM } | Where-Object { $_.Count -gt 1 })
Write-Host "Possiveis duplicados (mantidos, so sinalizados): $($dups.Count)"
foreach ($g in $dups) { Write-Host ("   - " + (($g.Group | ForEach-Object { $_.NumAntigo }) -join ', ')) }
Write-Host ""

$naoMapeados = @($ordenados | Group-Object ChaveA | Where-Object { ($_.Group | Select-Object -ExpandProperty Artista -Unique).Count -gt 1 })
Write-Host "Artistas com grafias diferentes ainda nao unificadas: $($naoMapeados.Count)"
foreach ($g in $naoMapeados) { Write-Host ("   - " + (($g.Group | Select-Object -ExpandProperty Artista -Unique) -join ' | ')) }

# 5) CSV de conferencia (sempre gerado, mesmo na simulacao)
$log = Join-Path $PSScriptRoot "mapeamento_renomeacao.csv"
$ordenados | Select-Object `
    @{n='NumNovo';e={$_.NumNovo}}, `
    @{n='NumAntigo';e={$_.NumAntigo}}, `
    @{n='NomeAntigo';e={$_.Arquivo.Name}}, `
    @{n='NomeNovo';e={$_.NovoNome}} |
    Export-Csv -LiteralPath $log -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Mapeamento salvo em: $log"

if (-not $Executar) {
    Write-Host "SIMULACAO: nada foi renomeado. Confira o CSV e rode com -Executar para aplicar."
    return
}

# 6) Renomear em duas etapas (evita colisao de nomes). Nada e apagado.
Write-Host "Renomeando (etapa 1: nomes temporarios)..."
foreach ($it in $ordenados) {
    Rename-Item -LiteralPath $it.Arquivo.FullName -NewName ("__tmp_{0}.mp4" -f $it.NumNovo)
}
Write-Host "Renomeando (etapa 2: nomes finais)..."
foreach ($it in $ordenados) {
    $tmp = Join-Path $Pasta ("__tmp_{0}.mp4" -f $it.NumNovo)
    Rename-Item -LiteralPath $tmp -NewName $it.NovoNome
}
Write-Host "Pronto. $($ordenados.Count) arquivos renumerados em sequencia."
