# В проекте нет гема rails-i18n, поэтому правила множественного числа
# русского языка (config/locales/plurals.rb) включаются вручную
I18n::Backend::Simple.include(I18n::Backend::Pluralization)
