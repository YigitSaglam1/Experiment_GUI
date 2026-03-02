using System.Globalization;

public static class InputValidation
{
    public static bool TryGetFloat(string input, out float value)
    {
        value = 0f;

        if (string.IsNullOrWhiteSpace(input))
            return false;

        input = input.Trim();

        // Try invariant first (expects '.' as decimal)
        if (float.TryParse(input, NumberStyles.Float, CultureInfo.InvariantCulture, out value))
            return true;

        // Fallback to user's current locale (might use ',' as decimal)
        return float.TryParse(input, NumberStyles.Float, CultureInfo.CurrentCulture, out value);
    }
}