import com.jidesoft.grid.CellStyle;
import com.jidesoft.grid.Property;
import com.jidesoft.grid.PropertyTableModel;
import com.jidesoft.grid.StyleModel;

import java.util.List;

public class StylePropertyTableModel<T extends Property> extends PropertyTableModel<T> implements StyleModel {

    static CellStyle cellStyle = new CellStyle();

    public StylePropertyTableModel(List<T> list) {
        super(list);
    }

    @Override
    public CellStyle getCellStyleAt(int row, int column) {
        return cellStyle;
    }

    @Override
    public boolean isCellStyleOn() {
        return true;
    }

    public void setCellStyle(CellStyle style) {
        cellStyle = style;
    }
}
