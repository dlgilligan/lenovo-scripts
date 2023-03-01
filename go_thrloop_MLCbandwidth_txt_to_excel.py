from openpyxl import Workbook
import re
from openpyxl.chart import (
    ScatterChart,
    Reference,
    Series,
)
import pandas as pd # For optimized version of the script



# Get inputs
print("Enter Number of Cores in CPU:")
noc = int(input())
print("\nEnter Input Filename (include .txt):")
filename_in = input()
print("\nEnter Output Filename (include .xlsx):")
filename_out = input()


# Create a 2D matrix to store the values from the text file
rows, cols = (int(noc/2), 4)
values = [[0 for i in range(cols)] for j in range(rows)]

# Create Workbook and Empty Sheet
wb = Workbook()
worksheet = wb.active

# Fill in the Column Names
worksheet['A1'] = "Cores"
worksheet['B1'] = "ALL"
worksheet['C1'] = "3:1"
worksheet['D1'] = "2:1"
worksheet['E1'] = "1:1"

# Fill in the number of cores column 
cell_idx = 2
for i in range(2,noc + 1,2) :
    worksheet['A'+str(cell_idx)] = i
    cell_idx += 1



line_count = 0

# Fill in the 2D matrix
with open(filename_in) as f :

    lines = f.readlines() # Reads all lines from the text file 

    for i in range(4) : # Columns
        for j in range(int(noc/2)) : # Rows

            if(line_count < (int(noc/2) * 12)) :
                line_count += 12 # B/W is every 12 lines starting at 13
            else :
                line_count += 11 # After ALL, every 11 lines

            line = lines[line_count] # Extracts line containing B/W


            nums_list = re.findall("\d+\.\d+",line)  # Seperates line into 3 tokens
            num = nums_list[1] # Extracts B/W from list

            values[j][i] = float(num) # 

# Fill in cells on worksheet one row at a time
for i in range(0,int(noc / 2)) :
    
    j = str(i + 2);

    worksheet['B'+j] = values[i][0]
    worksheet['C'+j] = values[i][1]
    worksheet['D'+j] = values[i][2]
    worksheet['E'+j] = values[i][3]

# Create a plot to display information
chart = ScatterChart()
chart.title = "Results of MLC"
chart.style = 18
chart.x_axis.title = 'Number of Cores'
chart.y_axis.title = 'Bandwidth (MB/s)'
chart.x_axis.scaling.max = noc + 5
chart.x_axis.scaling.min = 0

xvalues = Reference(worksheet, min_col=1, min_row=2, max_row=int(noc/2) + 1)

for i in range(2, 6):
    values = Reference(worksheet, min_col=i, min_row=1, max_row=int(noc/2) + 1)
    series = Series(values, xvalues,title_from_data = True)
    chart.series.append(series)

worksheet.add_chart(chart, "G19")


#Save File
wb.save(filename = filename_out)

