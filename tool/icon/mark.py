BLU="#1D3A8A"; ARANCIO="#F28C38"; CARTA="#FFF8F0"; PIEGA="#C96E22"

def house(fill_body=CARTA, roof=ARANCIO, fold=PIEGA, sym=BLU, dot=ARANCIO):
    return f'''
  <!-- casa-documento -->
  <path d="M28 50 L54 28 L80 50 V84 Q80 89 75 89 H33 Q28 89 28 84 Z" fill="{fill_body}"/>
  <!-- tetto arancio, piegato come l'angolo di un foglio -->
  <path d="M20 52 L54 22 L88 52 L82 57 L54 33 L26 57 Z" fill="{roof}"/>
  <path d="M82 57 L88 52 L88 60 Z" fill="{fold}"/>
  <!-- simbolo: grafico a torta (spazio) -->
  <path d="M52 71.5 L65 71.5 A13 13 0 1 1 52 58.5 Z" fill="{sym}"/>
  <path d="M55 68.5 L55 55.5 A13 13 0 0 1 68 68.5 Z" fill="{sym}"/>
  <!-- puntino -->
  <circle cx="90" cy="90" r="4.5" fill="{dot}"/>'''

def full():
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><rect width="108" height="108" rx="26" fill="{BLU}"/>{house()}</svg>'

def fg(mono=False):
    g = house()
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><g transform="translate(54 54) scale(0.8) translate(-54 -55)">{g}</g></svg>'
