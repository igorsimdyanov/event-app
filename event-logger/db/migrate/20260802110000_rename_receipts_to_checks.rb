class RenameReceiptsToChecks < ActiveRecord::Migration[8.0]
  def change
    rename_table :receipts, :checks
    rename_column :events, :receipt_id, :check_id
  end
end
