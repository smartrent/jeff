%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 86400},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},

        # Report TODO comments, but don't fail the check
        {Credo.Check.Design.TagTODO, exit_status: 0}
      ]
    }
  ]
}
