%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: [
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 86400},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        {Credo.Check.Readability.Specs, tags: []},

        # Report TODO comments, but don't fail the check
        {Credo.Check.Design.TagTODO, exit_status: 0}
      ]
    }
  ]
}
