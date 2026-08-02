# Правила множественного числа русского языка (CLDR).
# ActiveAdmin запрашивает названия ресурсов с дробным count — для них
# используется форма :other.
{
  ru: {
    i18n: {
      plural: {
        keys: %i[one few many other],
        rule: lambda { |count|
          next :other unless count.is_a?(Integer)

          mod10 = count.abs % 10
          mod100 = count.abs % 100

          if mod10 == 1 && mod100 != 11
            :one
          elsif (2..4).cover?(mod10) && !(12..14).cover?(mod100)
            :few
          else
            :many
          end
        }
      }
    }
  }
}
