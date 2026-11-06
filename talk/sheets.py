from PIL import Image, ImageDraw
import glob, os, sys
d = sys.argv[1]
files = sorted(glob.glob(os.path.join(d, 'p*.png')))
print(len(files), 'pages', Image.open(files[0]).size)
per, cols = 6, 3
for i in range(0, len(files), per):
    chunk = files[i:i+per]; ims = [Image.open(f) for f in chunk]
    w = max(im.width for im in ims); h = max(im.height for im in ims); rows = (len(chunk)+cols-1)//cols
    sheet = Image.new('RGB', (cols*(w+10)+10, rows*(h+30)+10), 'white'); dr = ImageDraw.Draw(sheet)
    for k, im in enumerate(ims):
        x = 10+(k%cols)*(w+10); y = 10+(k//cols)*(h+30); sheet.paste(im, (x, y+20)); dr.text((x, y+2), os.path.basename(chunk[k]), fill='red')
    sheet.save(os.path.join(d, f'sheet{i//per+1:02d}.png'))
print('sheets', len(glob.glob(os.path.join(d, 'sheet*.png'))))
