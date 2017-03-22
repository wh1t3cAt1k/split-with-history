# Split With History

A PowerShell script that allows to extract lines from a file into another file, preserving git history in both files.

# Example usage:

```
splitwithhistory -s 20 -e 70 -p 'AC-82445' -o 'WebSites\Pure\PX.Objects\AR\Descriptor\Attribute.cs' -t 'WebSites\Pure\PX.Objects\AR\Descriptor\NewAttribute.cs'
```

# Parameters

- `-s` or `-start` - the number of the first line (inclusive) to be extracted to a separate file. *Required*.
- `-e` or `-end` - the number of the last line (inclusive) to be extracted to a separate file. *Required*.
- `-p` or `-commitPrefix` - _optional_ prefix of the automatic commits that will be made in the git repository.
- `-t` - the target file name, to which the specified part of the source file will be extracted. *Required*.
- `-tr` - _optional_ new name for the source file.
- `-b1` - _optional_ name of the first temporary branch that will be used to create a necessary merge conflict. By default, equals `splitwithhistorytemporaryhistorybranch1`.
- `-b2` - _optional_ name of the first temporary branch that will be used to create a necessary merge conflict. By default, equals `splitwithhistorytemporaryhistorybranch2`.

# Words of caution

The branches specified by the `-b1` and `-b2` parameters will be created and deleted automatically.