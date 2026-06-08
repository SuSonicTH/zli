local header = [[<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
]]

local function getDateTime(tbl)
    if tbl.year ~= nil and tbl.hour ~= nil then
        return 'DateTime',
            string.format("%d-%02d-%02dT%02d:%02d:%02d.000",
                tbl.year, tbl.month, tbl.day, tbl.hour, tbl.min, tbl.sec
            )
    elseif tbl.year ~= nil then
        return 'ShortDate',
            string.format("%d-%02d-%02dT00:00:00.000",
                tbl.year, tbl.month, tbl.day
            )
    elseif tbl.hour ~= nil then
        return 'Time',
            string.format("1899-12-31T%02d:%02d:%02d.000",
                tbl.hour, tbl.min, tbl.sec
            )
    else
        return nil
    end
end

return function(filename)
    arg_check_type("xlsxmlwriter.new", 1, filename, 3, 'string')
    local file, err = io.open(filename, "wb")
    if file == nil then
        error("could not open file " .. filename .. ' for writing: ' .. err, 3)
    end

    file:write(header)

    local xls = {
        filename = filename,
        file = file,
        worksheetOpen = false,
        sheetCount = 0,
        rowOpen = false,
        row = 0,
    }

    function xls:newSheet(name)
        xls:closeSheet()
        if name == nil then
            name = "Sheet" .. (xls.sheetCount + 1)
        end
        xls.file:write('<Worksheet ss:Name="', name, '">\n')
        xls.file:write('<Table ss:DefaultColumnWidth="48" ss:DefaultRowHeight="14.4">\n')
        xls.sheetCount = xls.sheetCount + 1
        xls.worksheetOpen = true
        return xls
    end

    function xls:closeSheet()
        xls:endRow()
        if xls.worksheetOpen then
            xls.file:write("</Table>\n</Worksheet>\n")
            xls.worksheetOpen = false
        end
        return xls
    end

    function xls:nextRow(...)
        xls:endRow()
        xls.row = xls.row + 1
        xls.file:write('<Row>')
        xls.rowOpen = true

        if select('#', ...) > 0 then
            xls:cells(...)
        end
        return xls
    end

    function xls:assertRowOpen()
        if not xls.rowOpen then
            xls:nextRow()
        end
        return xls
    end

    function xls:endRow()
        if xls.rowOpen then
            xls.file:write('</Row>\n')
            xls.rowOpen = false
        end
        return xls
    end

    function xls:addRow(tbl)
        arg_check_type("xlsxmlwriter.addRow", 1, tbl, 3, 'table')
        return xls:nextRow(table.unpack(tbl))
    end

    function xls:cells(...)
        for _, value in ipairs { ... } do
            xls:cell(value)
        end
        return xls
    end

    function xls:addCells(tbl)
        arg_check_type("xlsxmlwriter.addCells", 1, tbl, 3, 'table')
        return xls:cells(table.unpack(tbl))
    end

    function xls:cell(value)
        xls:assertRowOpen()
        local valueType = type(value)
        if valueType == 'string' then
            xls.file:write('<Cell><Data ss:Type="String">', value, '</Data></Cell>')
        elseif valueType == 'number' then
            xls.file:write('<Cell><Data ss:Type="Number">', value, '</Data></Cell>')
        elseif valueType == 'table' then
            local dateFormat, timeStamp = getDateTime(value)
            if dateFormat then
                xls.file:write('<Cell ss:StyleID="', dateFormat, '"><Data ss:Type="DateTime">', timeStamp,
                    '</Data></Cell>')
            else
                return xls:cell(tostring(value))
            end
        else
            return xls:cell(tostring(value))
        end
        return xls
    end

    function xls:close()
        xls:closeSheet()
        xls.file:write("</Workbook>")
        xls.file:close()
        return xls
    end

    return xls
end
