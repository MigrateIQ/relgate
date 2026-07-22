using System;
using System.Text;

namespace Dirty;

public static class Program
{
    public static void Main()
    {
        string? maybeNull = null;
        string definitelyNotNull = maybeNull;
        Console.WriteLine(definitelyNotNull);
    }
}
