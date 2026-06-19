local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local xlswriter = require "xlsxmlwriter"
Test_xlsxmlwriter = {}

local expected = [[<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
    xmlns:o="urn:schemas-microsoft-com:office:office"
    xmlns:x="urn:schemas-microsoft-com:office:excel"
    xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
    xmlns:html="http://www.w3.org/TR/REC-html40"
    xmlns:dt="uuid:C2F41010-65B3-11d1-A29F-00AA00C14882">
    <Styles>
        <Style ss:ID="Time">
            <NumberFormat ss:Format="hh:mm:ss" />
        </Style>
        <Style ss:ID="ShortDate">
            <NumberFormat ss:Format="yyyy\/mm\/dd" />
        </Style>
        <Style ss:ID="DateTime">
            <NumberFormat ss:Format="yyyy\/mm\/dd\ hh:mm:ss" />
        </Style>
    </Styles>
<Worksheet ss:Name="test1">
<Table ss:DefaultColumnWidth="48" ss:DefaultRowHeight="14.4">
<Row><Cell><Data ss:Type="String">A</Data></Cell><Cell><Data ss:Type="String">B</Data></Cell><Cell><Data ss:Type="String">C</Data></Cell></Row>
<Row><Cell><Data ss:Type="Number">1</Data></Cell><Cell><Data ss:Type="Number">2</Data></Cell><Cell><Data ss:Type="Number">3</Data></Cell><Cell><Data ss:Type="Number">4</Data></Cell></Row>
<Row><Cell><Data ss:Type="Number">1.1</Data></Cell><Cell><Data ss:Type="Number">2.2</Data></Cell><Cell><Data ss:Type="Number">3.3</Data></Cell><Cell><Data ss:Type="Number">4.4</Data></Cell></Row>
<Row><Cell ss:StyleID="ShortDate"><Data ss:Type="DateTime">2026-05-23T00:00:00.000</Data></Cell><Cell ss:StyleID="DateTime"><Data ss:Type="DateTime">2025-12-24T16:30:25.000</Data></Cell><Cell ss:StyleID="Time"><Data ss:Type="DateTime">1899-12-31T23:59:59.000</Data></Cell></Row>
</Table>
</Worksheet>
<Worksheet ss:Name="test2">
<Table ss:DefaultColumnWidth="48" ss:DefaultRowHeight="14.4">
<Row><Cell><Data ss:Type="String">Another sheet with a longer text cell</Data></Cell></Row>
</Table>
</Worksheet>
</Workbook>]]

function Test_xlsxmlwriter:Test_write_excel_file()
    local filename = "./test/temp/xlswriter.xls"
    xlswriter(filename)
        :newSheet("test1")
        :cells('A', 'B', 'C'):endRow()
        :addCells { 1, 2, 3 }:cell(4)
        :addRow { 1.1, 2.2, 3.3 }:cell(4.4)
        :nextRow()
        :cell { year = 2026, month = 5, day = 23 }
        :cell { year = 2025, month = 12, day = 24, hour = 16, min = 30, sec = 25 }
        :cell { hour = 23, min = 59, sec = 59 }
        :newSheet("test2")
        :cell("Another sheet with a longer text cell")
        :close()
    lu.assertEquals(expected, io.read_file(filename))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
